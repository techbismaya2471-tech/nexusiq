public class CircuitBreakerService extends NexusIQServiceBase {
    
    private static final Integer FAILURE_THRESHOLD = 3;
    private static final Integer RETRY_MINUTES = 30;
    
    // CHECK — Is system ka circuit OPEN hai ya CLOSED?
    public static Boolean isCircuitOpen(String systemName) {
        Circuit_Breaker__c cb = NexusIQSelectorBase.getCircuitBreaker(systemName);
        
        if(cb == null) return false;
        
        if(cb.Status__c == 'OPEN') {
            // Retry time aa gaya? HALF_OPEN karo
            if(cb.Retry_After__c <= DateTime.now()) {
                updateCircuitStatus(cb, 'HALF_OPEN');
                return false;
            }
            return true;
        }
        return false;
    }
    
    // RECORD — Failure hua
    public static void recordFailure(String systemName) {
        Circuit_Breaker__c cb = NexusIQSelectorBase.getCircuitBreaker(systemName);
        
        if(cb == null) return;
        
        cb.Failure_Count__c = (cb.Failure_Count__c == null ? 0 : cb.Failure_Count__c) + 1;
        cb.Last_Failure_Time__c = DateTime.now();
        
        // Threshold cross hua? OPEN karo
        if(cb.Failure_Count__c >= FAILURE_THRESHOLD) {
            cb.Status__c = 'OPEN';
            cb.Retry_After__c = DateTime.now().addMinutes(RETRY_MINUTES);
            System.debug('NexusIQ Circuit OPENED for: ' + systemName);
            System.enqueueJob(new CircuitBreakerQueueable(systemName, 'OPEN', 'TXN-AUTO-' + systemName));
            NexusIQEventPublisher.publishCircuitOpen('TXN-AUTO-' + systemName, systemName);
        }
        update cb;
    }
    
    // RESET — Success hua
    public static void recordSuccess(String systemName) {
        Circuit_Breaker__c cb = NexusIQSelectorBase.getCircuitBreaker(systemName);
        
        if(cb == null) return;
        
        cb.Status__c = 'CLOSED';
        cb.Failure_Count__c = 0;
        cb.Retry_After__c = null;
        update cb;
    }
    
    // Helper — Status update karo
    private static void updateCircuitStatus(Circuit_Breaker__c cb, String status) {
        cb.Status__c = status;
        update cb;
    }
}