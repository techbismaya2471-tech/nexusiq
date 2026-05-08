public class CircuitBreakerQueueable implements Queueable {
    
    private String systemName;
    private String action; // 'OPEN' or 'RESET'
    private String correlationId;
    
    public CircuitBreakerQueueable(String systemName, String action, String correlationId) {
        this.systemName = systemName;
        this.action = action;
        this.correlationId = correlationId;
    }
    
    public void execute(QueueableContext context) {
        System.debug('NexusIQ Queueable Running: ' + action + ' for ' + systemName);
        
        if(action == 'OPEN') {
            CircuitBreakerService.recordFailure(systemName);
            createDLQEntry();
        } else if(action == 'RESET') {
            CircuitBreakerService.recordSuccess(systemName);
        }
        
        NexusIQUtils.log(correlationId, 'Queueable completed: ' + action + ' | System: ' + systemName);
    }
    
    // Failed request ko DLQ mein daalo
    private void createDLQEntry() {
        Dead_Letter_Queue__c dlq = new Dead_Letter_Queue__c();
        dlq.System_Name__c = systemName;
        dlq.Status__c = 'PENDING';
        dlq.Correlation_Id__c = correlationId;
        dlq.Retry_Count__c = 0;
        dlq.Max_Retries__c = 3;
        dlq.Next_Retry_Time__c = DateTime.now().addMinutes(5);
        dlq.Error_Message__c = 'Circuit Breaker OPENED — request queued for retry';
        insert dlq;
        
        System.debug('NexusIQ DLQ Entry Created: ' + correlationId);
    }
}