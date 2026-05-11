public class NexusIQOrderQueueable implements Queueable, Database.AllowsCallouts {
    
    private NexusIQ_Order__c order;
    
    public NexusIQOrderQueueable(NexusIQ_Order__c order) {
        this.order = order;
    }
    
    public void execute(QueueableContext context) {
        String corrId = NexusIQUtils.generateCorrelationId();
        Boolean success = true;
        String errorMessage = '';
        String failedSystem = '';
        
        try {
            // ── STEP 1: SAP Stock Check ─────────────
            if(CircuitBreakerService.isCircuitOpen('SAP')) {
                throw new NexusIQException('SAP Circuit OPEN — fast fail');
            }
            HttpRequest sapReq = new HttpRequest();
            sapReq.setEndpoint('callout:SAP_NC/api/sap/stock-check?item=' + 
                              order.Item__c + '&quantity=' + 
                              order.Quantity__c + '&correlationId=' + corrId);
            sapReq.setMethod('GET');
            sapReq.setTimeout(10000);
            HttpResponse sapRes = new Http().send(sapReq);
            if(sapRes.getStatusCode() != 200) {
                failedSystem = 'SAP';
                throw new NexusIQException('SAP failed: ' + sapRes.getStatusCode());
            }
            NexusIQUtils.log(corrId, 'SAP', 'SUCCESS', 'Stock check done', null, sapRes.getBody());

            // ── STEP 2: Stripe Payment ──────────────
            if(CircuitBreakerService.isCircuitOpen('Stripe')) {
                throw new NexusIQException('Stripe Circuit OPEN — fast fail');
            }
            HttpRequest stripeReq = new HttpRequest();
            stripeReq.setEndpoint('callout:STRIPE_NC/api/stripe/charge');
            stripeReq.setMethod('POST');
            stripeReq.setHeader('Content-Type', 'application/json');
            stripeReq.setBody('{"correlationId":"' + corrId + 
                             '","amount":' + order.Amount__c + 
                             ',"currency":"INR","customer":"' + 
                             order.Customer_Name__c + '"}');
            stripeReq.setTimeout(10000);
            HttpResponse stripeRes = new Http().send(stripeReq);
            if(stripeRes.getStatusCode() != 200) {
                failedSystem = 'Stripe';
                throw new NexusIQException('Stripe failed: ' + stripeRes.getStatusCode());
            }
            NexusIQUtils.log(corrId, 'Stripe', 'SUCCESS', 'Payment charged', null, stripeRes.getBody());

            // ── STEP 3: S3 Contract Upload ──────────
            if(CircuitBreakerService.isCircuitOpen('S3')) {
                throw new NexusIQException('S3 Circuit OPEN — fast fail');
            }
            HttpRequest s3Req = new HttpRequest();
            s3Req.setEndpoint('callout:S3_NC/api/s3/upload');
            s3Req.setMethod('POST');
            s3Req.setHeader('Content-Type', 'application/json');
            s3Req.setBody('{"correlationId":"' + corrId + 
                         '","fileName":"contract_' + corrId + 
                         '.pdf","content":"Base64Contract","folder":"contracts"}');
            s3Req.setTimeout(10000);
            HttpResponse s3Res = new Http().send(s3Req);
            if(s3Res.getStatusCode() != 200) {
                failedSystem = 'S3';
                throw new NexusIQException('S3 failed: ' + s3Res.getStatusCode());
            }
            NexusIQUtils.log(corrId, 'S3', 'SUCCESS', 'Contract uploaded', null, s3Res.getBody());

            // ── STEP 4: Twilio SMS ──────────────────
            if(CircuitBreakerService.isCircuitOpen('Twilio')) {
                throw new NexusIQException('Twilio Circuit OPEN — fast fail');
            }
            HttpRequest twilioReq = new HttpRequest();
            twilioReq.setEndpoint('callout:TWILIO_NC/api/twilio/sms');
            twilioReq.setMethod('POST');
            twilioReq.setHeader('Content-Type', 'application/json');
            twilioReq.setBody('{"correlationId":"' + corrId + 
                             '","to":"+919876543210","message":"Order confirmed! ' + 
                             order.Item__c + ' x' + order.Quantity__c + 
                             '. Ref: ' + corrId + '"}');
            twilioReq.setTimeout(10000);
            HttpResponse twilioRes = new Http().send(twilioReq);
            if(twilioRes.getStatusCode() != 200) {
                failedSystem = 'Twilio';
                throw new NexusIQException('Twilio failed: ' + twilioRes.getStatusCode());
            }
            NexusIQUtils.log(corrId, 'Twilio', 'SUCCESS', 'SMS sent', null, twilioRes.getBody());

        } catch(Exception e) {
            success = false;
            errorMessage = e.getMessage();
        }

        // ── SAARE CALLOUTS KE BAAD — DML ───────────
        if(success) {
            // CB Success update
            CircuitBreakerService.recordSuccess('SAP');
            CircuitBreakerService.recordSuccess('Stripe');
            CircuitBreakerService.recordSuccess('S3');
            CircuitBreakerService.recordSuccess('Twilio');

            // SAGA start + complete
            SagaOrchestratorService.startSaga(corrId, 4,
                '{"item":"' + order.Item__c + '","qty":' + 
                order.Quantity__c + ',"customer":"' + 
                order.Customer_Name__c + '"}');
            SagaOrchestratorService.completeStep(corrId, 1);
            SagaOrchestratorService.completeStep(corrId, 2);
            SagaOrchestratorService.completeStep(corrId, 3);
            SagaOrchestratorService.completeStep(corrId, 4);

            // Logs flush
            NexusIQUtils.flushLogs();

            // Order Completed
            NexusIQ_Order__c orderToUpdate = new NexusIQ_Order__c(
                Id = order.Id,
                Status__c = 'Completed',
                Correlation_Id__c = corrId,
                Error_Message__c = '' 
            );
            update orderToUpdate;

        } else {
            // CB Failure update
            if(String.isNotBlank(failedSystem)) {
                CircuitBreakerService.recordFailure(failedSystem);
            }

            // SAGA fail
            SagaOrchestratorService.startSaga(corrId, 4,
                '{"item":"' + order.Item__c + '","qty":' + 
                order.Quantity__c + ',"customer":"' + 
                order.Customer_Name__c + '"}');
            SagaOrchestratorService.failSaga(corrId, errorMessage);
            NexusIQUtils.flushLogs();

            // Order Failed
            NexusIQ_Order__c orderToUpdate = new NexusIQ_Order__c(
                Id = order.Id,
                Status__c = 'Failed',
                Correlation_Id__c = corrId,
                Error_Message__c = errorMessage
            );
            update orderToUpdate;
        }
    }
    
    public class NexusIQException extends Exception {}
}