public class NexusIQEventPublisher {
    
    // SAGA step complete event publish karo
    public static void publishSagaStepComplete(String correlationId, String systemName, Integer step) {
        NexusIQ_Event__e event = new NexusIQ_Event__e();
        event.Correlation_Id__c = correlationId;
        event.Event_Type__c = 'SAGA_STEP_COMPLETE';
        event.System_Name__c = systemName;
        event.Status__c = 'SUCCESS';
        event.Payload__c = 'Step ' + step + ' completed for ' + systemName;
        
        Database.SaveResult result = EventBus.publish(event);
        
        if(result.isSuccess()) {
            System.debug('NexusIQ Event Published: SAGA_STEP_COMPLETE | ' + correlationId);
        } else {
            System.debug('NexusIQ Event Publish FAILED: ' + result.getErrors());
        }
    }
    
    // SAGA fail event publish karo
    public static void publishSagaFailed(String correlationId, String systemName, String errorMessage) {
        NexusIQ_Event__e event = new NexusIQ_Event__e();
        event.Correlation_Id__c = correlationId;
        event.Event_Type__c = 'SAGA_FAILED';
        event.System_Name__c = systemName;
        event.Status__c = 'FAILED';
        event.Payload__c = errorMessage;
        
        Database.SaveResult result = EventBus.publish(event);
        System.debug('NexusIQ Event Published: SAGA_FAILED | ' + correlationId);
    }
    
    // Circuit Breaker open event publish karo
    public static void publishCircuitOpen(String correlationId, String systemName) {
        NexusIQ_Event__e event = new NexusIQ_Event__e();
        event.Correlation_Id__c = correlationId;
        event.Event_Type__c = 'CIRCUIT_OPEN';
        event.System_Name__c = systemName;
        event.Status__c = 'OPEN';
        event.Payload__c = 'Circuit Breaker OPENED for: ' + systemName;
        
        Database.SaveResult result = EventBus.publish(event);
        System.debug('NexusIQ Event Published: CIRCUIT_OPEN | ' + systemName);
    }
}