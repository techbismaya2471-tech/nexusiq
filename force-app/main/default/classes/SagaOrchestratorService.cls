public class SagaOrchestratorService extends NexusIQServiceBase {
    
    public static SAGA_Transaction__c startSaga(String correlationId, Integer totalSteps, String payload) {
        SAGA_Transaction__c saga = new SAGA_Transaction__c();
        saga.Correlation_Id__c = correlationId;
        saga.Status__c = 'IN_PROGRESS';
        saga.Current_Step__c = 1;
        saga.Total_Steps__c = totalSteps;
        saga.Payload__c = payload;
        saga.Compensation_Status__c = 'PENDING';
        saga.Steps_Detail__c = '{"SAP":"PENDING","Stripe":"PENDING","S3":"PENDING","Twilio":"PENDING"}';
        insert saga;
        System.debug('NexusIQ SAGA Started: ' + correlationId);
        return saga;
    }
    
    public static void completeStep(String correlationId, Integer completedStep) {
        SAGA_Transaction__c saga = getSaga(correlationId);
        if(saga == null) return;
        saga.Current_Step__c = completedStep + 1;
        if(completedStep >= saga.Total_Steps__c) {
            saga.Status__c = 'COMPLETED';
            // Success — sab steps COMPLETED
            saga.Steps_Detail__c = '{"SAP":"COMPLETED","Stripe":"COMPLETED","S3":"COMPLETED","Twilio":"COMPLETED"}';
        }
        update saga;
    }
    
    public static void failSagaAtStep(String correlationId, 
        String errorMessage, Integer completedSteps, String failedSystem) {
        SAGA_Transaction__c saga = getSaga(correlationId);
        if(saga == null) return;
        saga.Status__c = 'FAILED';
        saga.Current_Step__c = completedSteps + 1;
        saga.Error_Message__c = 'Failed at Step ' + (completedSteps + 1) + 
                                ' (' + failedSystem + '): ' + errorMessage;
        saga.Compensation_Status__c = 'IN_PROGRESS';
        
        // Steps_Detail — exact picture
        Map<String, String> steps = new Map<String, String>{
            'SAP' => 'PENDING',
            'Stripe' => 'PENDING',
            'S3' => 'PENDING',
            'Twilio' => 'PENDING'
        };
        String[] systems = new String[]{'SAP', 'Stripe', 'S3', 'Twilio'};
        for(Integer i = 0; i < systems.size(); i++) {
            if(i < completedSteps) {
                steps.put(systems[i], 'COMPLETED');
            } else if(systems[i] == failedSystem) {
                steps.put(systems[i], 'FAILED');
            } else {
                steps.put(systems[i], 'NOT_RUN');
            }
        }
        saga.Steps_Detail__c = JSON.serialize(steps);
        
        update saga;
        NexusIQEventPublisher.publishSagaFailed(correlationId, failedSystem, errorMessage);
    }
    
    public static void failSaga(String correlationId, String errorMessage) {
        SAGA_Transaction__c saga = getSaga(correlationId);
        if(saga == null) return;
        saga.Status__c = 'FAILED';
        saga.Error_Message__c = errorMessage;
        saga.Compensation_Status__c = 'IN_PROGRESS';
        update saga;
        NexusIQEventPublisher.publishSagaFailed(correlationId, 'SYSTEM', errorMessage);
        System.debug('NexusIQ SAGA Failed: ' + correlationId);
    }
    
    public static void recoverSaga(String correlationId) {
        SAGA_Transaction__c saga = getSaga(correlationId);
        if(saga == null) return;
        saga.Status__c = 'COMPLETED';
        saga.Error_Message__c = 'Recovered via DLQ retry';
        saga.Compensation_Status__c = 'COMPLETED';
        saga.Steps_Detail__c = '{"SAP":"COMPLETED","Stripe":"COMPLETED","S3":"COMPLETED","Twilio":"COMPLETED"}';
        update saga;
        System.debug('NexusIQ SAGA Recovered: ' + correlationId);
    }
    
    public static void completeSagaCompensation(String correlationId) {
        SAGA_Transaction__c saga = getSaga(correlationId);
        if(saga == null) return;
        saga.Compensation_Status__c = 'COMPLETED';
        update saga;
    }
    
    private static SAGA_Transaction__c getSaga(String correlationId) {
        List<SAGA_Transaction__c> records = [
            SELECT Id, Status__c, Current_Step__c, Total_Steps__c,
                   Error_Message__c, Compensation_Status__c, Payload__c,
                   Steps_Detail__c
            FROM SAGA_Transaction__c
            WHERE Correlation_Id__c = :correlationId
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }
}