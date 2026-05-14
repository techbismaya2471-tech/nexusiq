public class CircuitBreakerQueueable implements Queueable {
    
    private String systemName;
    private String action;
    private String correlationId;
    private String payload;
    
    public CircuitBreakerQueueable(String systemName, String action, 
                                    String correlationId, String payload) {
        this.systemName    = systemName;
        this.action        = action;
        this.correlationId = correlationId;
        this.payload       = payload;
    }
    
    public void execute(QueueableContext context) {
        System.debug('NexusIQ CB Queueable: ' + action + ' for ' + systemName);
        
        // DLQ entry NAHI banate yahan —
        // CircuitBreakerService.recordFailure() mein already ban rahi hai!
        // OPEN pe sirf event publish karo
        if(action == 'OPEN') {
            // NexusIQUtils.log(correlationId, systemName, 
            //     'FAILED', 'Circuit Breaker OPENED — system down', null, null);
            // NexusIQUtils.flushLogs();
            System.debug('NexusIQ CB Queueable complete: ' + action);
        } else if(action == 'RESET') {
            CircuitBreakerService.recordSuccess(systemName);
        }
        
        System.debug('NexusIQ CB Queueable complete: ' + action);
    }
}