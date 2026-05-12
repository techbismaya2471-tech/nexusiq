public class CircuitBreakerQueueable implements Queueable {
    
    private String systemName;
    private String action;
    private String correlationId;
    private String payload;
    
    public CircuitBreakerQueueable(String systemName, String action, String correlationId, String payload) {
        this.systemName = systemName;
        this.action = action;
        this.correlationId = correlationId;
        this.payload = payload;
    }
    
    public void execute(QueueableContext context) {
        System.debug('NexusIQ Queueable Running: ' + action + ' for ' + systemName);
        
        if(action == 'OPEN') {
            createDLQEntry();
        } else if(action == 'RESET') {
            CircuitBreakerService.recordSuccess(systemName);
        }
        
        NexusIQUtils.log(correlationId, 'Queueable completed: ' + action + ' | System: ' + systemName);
    }
    
    private void createDLQEntry() {
        // Duplicate check
        List<Dead_Letter_Queue__c> existing = [
            SELECT Id FROM Dead_Letter_Queue__c 
            WHERE Correlation_Id__c = :correlationId
            AND System_Name__c = :systemName
            LIMIT 1
        ];
        if(!existing.isEmpty()) return;
        
        // CB closed hai toh mat banao
        Circuit_Breaker__c cb = NexusIQSelectorBase.getCircuitBreaker(systemName);
        if(cb != null && cb.Status__c == 'CLOSED') return;
        
        Dead_Letter_Queue__c dlq = new Dead_Letter_Queue__c();
        dlq.System_Name__c     = systemName;
        dlq.Status__c          = 'PENDING';
        dlq.Correlation_Id__c  = correlationId;
        dlq.Payload__c         = payload;
        dlq.Retry_Count__c     = 0;
        dlq.Max_Retries__c     = 3;
        dlq.Next_Retry_Time__c = DateTime.now().addMinutes(5);
        dlq.Error_Message__c   = 'Circuit Breaker OPENED — request queued for retry';
        insert dlq;
    }
}