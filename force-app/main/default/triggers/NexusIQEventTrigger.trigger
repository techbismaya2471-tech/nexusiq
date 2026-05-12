trigger NexusIQEventTrigger on NexusIQ_Event__e (after insert) {
    
    for(NexusIQ_Event__e event : Trigger.new) {
        
        String correlationId = event.Correlation_Id__c;
        String systemName = event.System_Name__c;
        String eventType = event.Event_Type__c;
        
        System.debug('NexusIQ Event Received: ' + eventType + ' | ' + correlationId);
        
        // SAGA step complete hua
        if(eventType == 'SAGA_STEP_COMPLETE') {
            System.debug('NexusIQ SAGA Step Complete: ' + systemName + ' | ' + correlationId);
        }
        
        // SAGA fail hua — compensation shuru karo
        if(eventType == 'SAGA_FAILED') {
            //SagaOrchestratorService.failSaga(correlationId, event.Payload__c);
            System.debug('NexusIQ SAGA Compensation Triggered: ' + correlationId);
        }
        
        // Circuit Breaker open hua
        if(eventType == 'CIRCUIT_OPEN') {
            System.debug('NexusIQ Circuit Open Event: ' + systemName);
        }
    }
}