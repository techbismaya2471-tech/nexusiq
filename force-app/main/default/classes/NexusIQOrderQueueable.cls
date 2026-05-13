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
        Integer completedSteps = 0;
        Integer failedStep = 0;
        
        try {
            // ── STEP 1: SAP ─────────────────────────
            if(CircuitBreakerService.isCircuitOpen('SAP')) {
                failedSystem = 'SAP';
                failedStep = 1;
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
                failedStep = 1;
                throw new NexusIQException('SAP failed: ' + sapRes.getStatusCode());
            }
            completedSteps = 1;

            // ── STEP 2: Stripe ──────────────────────
            if(CircuitBreakerService.isCircuitOpen('Stripe')) {
                failedSystem = 'Stripe';
                failedStep = 2;
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
                failedStep = 2;
                throw new NexusIQException('Stripe failed: ' + stripeRes.getStatusCode());
            }
            completedSteps = 2;

            // ── STEP 3: S3 ──────────────────────────
            if(CircuitBreakerService.isCircuitOpen('S3')) {
                failedSystem = 'S3';
                failedStep = 3;
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
                failedStep = 3;
                throw new NexusIQException('S3 failed: ' + s3Res.getStatusCode());
            }
            completedSteps = 3;

            // ── STEP 4: Twilio ──────────────────────
            if(CircuitBreakerService.isCircuitOpen('Twilio')) {
                failedSystem = 'Twilio';
                failedStep = 4;
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
                failedStep = 4;
                throw new NexusIQException('Twilio failed: ' + twilioRes.getStatusCode());
            }
            completedSteps = 4;

        } catch(Exception e) {
            success = false;
            errorMessage = e.getMessage();
            NexusIQUtils.log(corrId, failedSystem, 'FAILED', e.getMessage(), null, null);
        }

        // ── SAARE CALLOUTS KE BAAD — DML ───────────
        String sagaPayload = '{"item":"' + order.Item__c + 
            '","qty":' + order.Quantity__c + 
            ',"customer":"' + order.Customer_Name__c + '"}';

        if(success) {
            CircuitBreakerService.recordSuccess('SAP');
            CircuitBreakerService.recordSuccess('Stripe');
            CircuitBreakerService.recordSuccess('S3');
            CircuitBreakerService.recordSuccess('Twilio');

            // SAGA start + complete — DML after callouts
            SagaOrchestratorService.startSaga(corrId, 4, sagaPayload);
            SagaOrchestratorService.completeStep(corrId, 1);
            SagaOrchestratorService.completeStep(corrId, 2);
            SagaOrchestratorService.completeStep(corrId, 3);
            SagaOrchestratorService.completeStep(corrId, 4);

            NexusIQUtils.flushLogs();

            NexusIQ_Order__c orderToUpdate = new NexusIQ_Order__c(
                Id = order.Id,
                Status__c = 'Completed',
                Correlation_Id__c = corrId,
                Error_Message__c = ''
            );
            update orderToUpdate;

        } else {
            // SAGA start + fail — DML after callouts
            SagaOrchestratorService.startSaga(corrId, 4, sagaPayload);
            SagaOrchestratorService.failSagaAtStep(
                corrId, errorMessage, completedSteps, failedSystem);

            if(String.isNotBlank(failedSystem)) {
                CircuitBreakerService.recordFailure(
                    failedSystem, corrId, buildPayload(corrId));
            }

            NexusIQUtils.flushLogs();

            NexusIQ_Order__c orderToUpdate = new NexusIQ_Order__c(
                Id = order.Id,
                Status__c = 'Failed',
                Correlation_Id__c = corrId,
                Error_Message__c = errorMessage
            );
            update orderToUpdate;
        }
    }

    private String buildPayload(String corrId) {
        return '{"item":"' + order.Item__c + 
               '","qty":' + order.Quantity__c + 
               ',"customer":"' + order.Customer_Name__c + 
               '","amount":' + order.Amount__c + 
               ',"orderId":"' + order.Id + '"}';
    }
    
    public class NexusIQException extends Exception {}
}