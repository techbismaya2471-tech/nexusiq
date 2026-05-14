public class DLQProcessor implements Schedulable, 
    Database.Batchable<sObject>, Database.AllowsCallouts {

    // ── SCHEDULABLE ────────────────────────────────────
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new DLQProcessor(), 10);
    }

    // ── BATCH START ────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime now = DateTime.now();
        return Database.getQueryLocator([
            SELECT Id, Name, System_Name__c, Payload__c,
                   Retry_Count__c, Max_Retries__c,
                   Next_Retry_Time__c, Error_Message__c,
                   Correlation_Id__c, Status__c
            FROM Dead_Letter_Queue__c
            WHERE Status__c = 'PENDING'
            AND Next_Retry_Time__c <= :now
            ORDER BY Next_Retry_Time__c ASC
        ]);
    }

    // ── BATCH EXECUTE ──────────────────────────────────
    public void execute(Database.BatchableContext bc,
                        List<Dead_Letter_Queue__c> dlqRecords) {

        List<Dead_Letter_Queue__c> toUpdate    = new List<Dead_Letter_Queue__c>();
        List<NexusIQ_Order__c>    orderUpdates = new List<NexusIQ_Order__c>();

        for(Dead_Letter_Queue__c dlq : dlqRecords) {
            Integer retryCount = dlq.Retry_Count__c != null ?
                                 Integer.valueOf(dlq.Retry_Count__c) : 0;
            Integer maxRetries = dlq.Max_Retries__c != null ?
                                 Integer.valueOf(dlq.Max_Retries__c) : 3;

            // New corrId for this retry attempt
            String newCorrId = NexusIQUtils.generateCorrelationId();

            try {
                Boolean success = retryCallout(dlq, newCorrId);

               if(success) {
    // ── DLQ RESOLVED ───────────────────
    dlq.Status__c        = 'RESOLVED';
    dlq.Resolved_At__c   = DateTime.now();
    dlq.Error_Message__c = ''; // FIXED — clear error message!
    NexusIQUtils.log(
        newCorrId, dlq.System_Name__c,
        'SUCCESS', 'DLQ retry succeeded', null, null
    );

    // ── CB Reset ───────────────────────
    CircuitBreakerService.recordSuccess('SAP');
    CircuitBreakerService.recordSuccess('Stripe');
    CircuitBreakerService.recordSuccess('S3');
    CircuitBreakerService.recordSuccess('Twilio');

    // ── SAGA COMPLETED ─────────────────
    // NAYA:
    SagaOrchestratorService.recoverSaga(
    dlq.Correlation_Id__c);
    // SagaOrchestratorService.completeSagaCompensation(
    //     dlq.Correlation_Id__c
    // );

    // ── Order COMPLETED ────────────────
    if(String.isNotBlank(dlq.Payload__c)) {
        Map<String, Object> p =
            (Map<String, Object>) JSON.deserializeUntyped(dlq.Payload__c);
        String orderId = (String) p.get('orderId');
        if(String.isNotBlank(orderId)) {
            orderUpdates.add(new NexusIQ_Order__c(
                Id                = orderId,
                Status__c         = 'Completed',
                Correlation_Id__c = newCorrId,
                Error_Message__c  = 'Recovered via DLQ retry'
            ));
        }
    }
}else {
    retryCount++;
    dlq.Retry_Count__c = retryCount;
    
    // ── CB Failure count++ ─────────────
    // CircuitBreakerService.recordFailure(
    //     dlq.System_Name__c, 
    //     newCorrId, 
    //     dlq.Payload__c
    // );
        CircuitBreakerService.recordFailureNoDLQ(
            dlq.System_Name__c);
    if(retryCount >= maxRetries) {
        dlq.Status__c = 'DEAD';
        dlq.Error_Message__c = 'Max retries (' + maxRetries + 
                               ') reached. Permanently failed.';
        NexusIQUtils.log(
            newCorrId, dlq.System_Name__c,
            'FAILED', dlq.Error_Message__c, null, null
        );
    } else {
        dlq.Status__c = 'PENDING';
        dlq.Next_Retry_Time__c = calculateNextRetry(retryCount);
        dlq.Error_Message__c = 'Retry ' + retryCount +
                               '/' + maxRetries + ' failed.';
    }
}

            } catch(Exception e) {
                retryCount++;
                dlq.Retry_Count__c   = retryCount;
                dlq.Error_Message__c = e.getMessage();

                if(retryCount >= maxRetries) {
                    dlq.Status__c = 'DEAD';
                } else {
                    dlq.Status__c          = 'PENDING';
                    dlq.Next_Retry_Time__c = calculateNextRetry(retryCount);
                }
            }

            toUpdate.add(dlq);
        }

        // ── DML — CALLOUTS KE BAAD ─────────────────────
        if(!toUpdate.isEmpty())    update toUpdate;
        if(!orderUpdates.isEmpty()) update orderUpdates;
        NexusIQUtils.flushLogs();
    }

    // ── BATCH FINISH ───────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug('DLQProcessor batch complete.');
    }

    // ── EXPONENTIAL BACKOFF ────────────────────────────
    private DateTime calculateNextRetry(Integer retryCount) {
        Integer baseMinutes = 2;
        Integer waitMinutes = (Integer) Math.pow(2, retryCount - 1) * baseMinutes;
        waitMinutes = Math.min(waitMinutes, 480);
        return DateTime.now().addMinutes(waitMinutes);
    }

    // ── REAL RETRY — SAP → Stripe → S3 → Twilio ───────
    private Boolean retryCallout(Dead_Letter_Queue__c dlq, String newCorrId) {
        try {
            // ── Payload Parse ──────────────────────────
            Map<String, Object> p =
                (Map<String, Object>) JSON.deserializeUntyped(dlq.Payload__c);
            String item     = (String) p.get('item');
            //String qty      = String.valueOf(p.get('qty'));
            Integer qtyInt = Integer.valueOf(String.valueOf(p.get('qty')).replace('.0',''));
                String qty = String.valueOf(qtyInt);
            String customer = (String) p.get('customer');
            String amount   = String.valueOf(p.get('amount'));

            // ── SAP Stock Check ────────────────────────
            HttpRequest sapReq = new HttpRequest();
            sapReq.setEndpoint('callout:SAP_NC/api/sap/stock-check?item=' +
                item + '&quantity=' + qty + '&correlationId=' + newCorrId);
            sapReq.setMethod('GET');
            sapReq.setTimeout(10000);
            HttpResponse sapRes = new Http().send(sapReq);
            if(sapRes.getStatusCode() != 200) return false;
            NexusIQUtils.log(newCorrId, 'SAP', 'SUCCESS',
                'DLQ Retry - Stock check done', null, sapRes.getBody());

            // ── Stripe Payment ─────────────────────────
            HttpRequest stripeReq = new HttpRequest();
            stripeReq.setEndpoint('callout:STRIPE_NC/api/stripe/charge');
            stripeReq.setMethod('POST');
            stripeReq.setHeader('Content-Type', 'application/json');
            stripeReq.setBody('{"correlationId":"' + newCorrId +
                '","amount":' + amount +
                ',"currency":"INR","customer":"' + customer + '"}');
            stripeReq.setTimeout(10000);
            HttpResponse stripeRes = new Http().send(stripeReq);
            if(stripeRes.getStatusCode() != 200) return false;
            NexusIQUtils.log(newCorrId, 'Stripe', 'SUCCESS',
                'DLQ Retry - Payment charged', null, stripeRes.getBody());

            // ── S3 Upload ──────────────────────────────
            HttpRequest s3Req = new HttpRequest();
            s3Req.setEndpoint('callout:S3_NC/api/s3/upload');
            s3Req.setMethod('POST');
            s3Req.setHeader('Content-Type', 'application/json');
            s3Req.setBody('{"correlationId":"' + newCorrId +
                '","fileName":"contract_' + newCorrId +
                '.pdf","content":"Base64Contract","folder":"contracts"}');
            s3Req.setTimeout(10000);
            HttpResponse s3Res = new Http().send(s3Req);
            if(s3Res.getStatusCode() != 200) return false;
            NexusIQUtils.log(newCorrId, 'S3', 'SUCCESS',
                'DLQ Retry - Contract uploaded', null, s3Res.getBody());

            // ── Twilio SMS ─────────────────────────────
            HttpRequest twilioReq = new HttpRequest();
            twilioReq.setEndpoint('callout:TWILIO_NC/api/twilio/sms');
            twilioReq.setMethod('POST');
            twilioReq.setHeader('Content-Type', 'application/json');
            twilioReq.setBody('{"correlationId":"' + newCorrId +
                '","to":"+919876543210","message":"Order recovered! ' +
                item + ' x' + qty + '. Ref: ' + newCorrId + '"}');
            twilioReq.setTimeout(10000);
            HttpResponse twilioRes = new Http().send(twilioReq);
            if(twilioRes.getStatusCode() != 200) return false;
            NexusIQUtils.log(newCorrId, 'Twilio', 'SUCCESS',
                'DLQ Retry - SMS sent', null, twilioRes.getBody());

            return true;

        } catch(Exception e) {
            return false;
        }
    }

    // ── STATIC HELPER — DLQ mein add karo ─────────────
    public static void addToDLQ(String systemName,
                                 String payload,
                                 String errorMessage,
                                 String correlationId) {
        Dead_Letter_Queue__c dlq = new Dead_Letter_Queue__c();
        dlq.System_Name__c     = systemName;
        dlq.Payload__c         = payload;
        dlq.Error_Message__c   = errorMessage;
        dlq.Correlation_Id__c  = correlationId;
        dlq.Status__c          = 'PENDING';
        dlq.Retry_Count__c     = 0;
        dlq.Max_Retries__c     = 3;
        dlq.Next_Retry_Time__c = DateTime.now().addMinutes(2);
        insert dlq;
    }
}