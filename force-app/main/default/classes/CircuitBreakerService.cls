public class CircuitBreakerService extends NexusIQServiceBase {
    
    private static final Integer FAILURE_THRESHOLD = 3;
    private static final Integer RETRY_MINUTES = 30;
    
    public static Boolean isCircuitOpen(String systemName) {
        Circuit_Breaker__c cb = NexusIQSelectorBase.getCircuitBreaker(systemName);
        if(cb == null) return false;
        if(cb.Status__c == 'OPEN') {
            if(cb.Retry_After__c <= DateTime.now()) {
                return false;
            }
            return true;
        }
        if(cb.Status__c == 'HALF_OPEN') {
            return false;
        }
        return false;
    }
    
    public static void recordFailure(String systemName, String correlationId, String payload) {
        Circuit_Breaker__c cb = NexusIQSelectorBase.getCircuitBreaker(systemName);
        if(cb == null) return;
        
        cb.Failure_Count__c = (cb.Failure_Count__c == null ? 0 : cb.Failure_Count__c) + 1;
        cb.Last_Failure_Time__c = DateTime.now();

        // ── HAR FAILURE PE DLQ ENTRY ──────────────
        List<Dead_Letter_Queue__c> existing = [
            SELECT Id FROM Dead_Letter_Queue__c
            WHERE Correlation_Id__c = :correlationId
            AND System_Name__c = :systemName
            LIMIT 1
        ];
        if(existing.isEmpty()) {
            Dead_Letter_Queue__c dlq = new Dead_Letter_Queue__c();
            dlq.System_Name__c     = systemName;
            dlq.Status__c          = 'PENDING';
            dlq.Correlation_Id__c  = correlationId;
            dlq.Payload__c         = payload;
            dlq.Retry_Count__c     = 0;
            dlq.Max_Retries__c     = 3;
            dlq.Next_Retry_Time__c = DateTime.now().addMinutes(5);
            dlq.Error_Message__c   = systemName + ' failed — queued for retry';
            insert dlq;
        }
        
        // ── CB THRESHOLD CHECK ────────────────────
        if(cb.Failure_Count__c >= FAILURE_THRESHOLD) {
            cb.Status__c = 'OPEN';
            cb.Retry_After__c = DateTime.now().addMinutes(RETRY_MINUTES);
             // FIXED — Batch context check!
            if(!System.isBatch()) {
                System.enqueueJob(new CircuitBreakerQueueable(
                    systemName, 'OPEN', correlationId, payload));
            }
            System.debug('NexusIQ Circuit OPENED for: ' + systemName);
            // System.enqueueJob(new CircuitBreakerQueueable(
            //     systemName, 'OPEN', correlationId, payload));
            NexusIQEventPublisher.publishCircuitOpen(correlationId, systemName);
        }
        update cb;
    }
    
    public static void recordSuccess(String systemName) {
        Circuit_Breaker__c cb = NexusIQSelectorBase.getCircuitBreaker(systemName);
        if(cb == null) return;
        cb.Status__c = 'CLOSED';
        cb.Failure_Count__c = 0;
        cb.Retry_After__c = null;
        update cb;
    }
    
    private static void updateCircuitStatus(Circuit_Breaker__c cb, String status) {
        cb.Status__c = status;
        update cb;
    }
}