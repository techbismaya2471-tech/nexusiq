public class SagaOrchestratorService extends NexusIQServiceBase {
    
    // SAGA shuru karo — naya transaction create karo
    public static SAGA_Transaction__c startSaga(String correlationId, Integer totalSteps, String payload) {
        SAGA_Transaction__c saga = new SAGA_Transaction__c();
        saga.Correlation_Id__c = correlationId;
        saga.Status__c = 'IN_PROGRESS';
        saga.Current_Step__c = 1;
        saga.Total_Steps__c = totalSteps;
        saga.Payload__c = payload;
        saga.Compensation_Status__c = 'PENDING';
        insert saga;
        
        System.debug('NexusIQ SAGA Started: ' + correlationId + ' | Steps: ' + totalSteps);
        return saga;
    }
    
    // Step complete hua — aage badho
    public static void completeStep(String correlationId, Integer completedStep) {
        SAGA_Transaction__c saga = getSaga(correlationId);
        if(saga == null) return;
        
        saga.Current_Step__c = completedStep + 1;
        
        // Sab steps done?
        if(completedStep >= saga.Total_Steps__c) {
            saga.Status__c = 'COMPLETED';
            System.debug('NexusIQ SAGA Completed: ' + correlationId);
        }
        update saga;
    }
    
    // Koi step fail hua — compensation shuru karo
    public static void failSaga(String correlationId, String errorMessage) {
        SAGA_Transaction__c saga = getSaga(correlationId);
        if(saga == null) return;
        
        saga.Status__c = 'FAILED';
        saga.Error_Message__c = errorMessage;
        saga.Compensation_Status__c = 'IN_PROGRESS';
        update saga;
        
        System.debug('NexusIQ SAGA Failed: ' + correlationId + ' | Compensation Starting...');
    }
    
    // Compensation complete hua — rollback done
    public static void completeSagaCompensation(String correlationId) {
        SAGA_Transaction__c saga = getSaga(correlationId);
        if(saga == null) return;
        
        saga.Compensation_Status__c = 'COMPLETED';
        update saga;
        
        System.debug('NexusIQ SAGA Compensation Completed: ' + correlationId);
    }
    
    // Helper — Correlation ID se SAGA record lao
    private static SAGA_Transaction__c getSaga(String correlationId) {
        List<SAGA_Transaction__c> records = [
            SELECT Id, Status__c, Current_Step__c, Total_Steps__c,
                   Error_Message__c, Compensation_Status__c, Payload__c
            FROM SAGA_Transaction__c
            WHERE Correlation_Id__c = :correlationId
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }
}