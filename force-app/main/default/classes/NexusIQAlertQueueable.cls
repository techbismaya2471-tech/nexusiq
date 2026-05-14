public class NexusIQAlertQueueable implements Queueable {
    
    private String systemName;
    private String correlationId;
    
    public NexusIQAlertQueueable(String systemName, String correlationId) {
        this.systemName    = systemName;
        this.correlationId = correlationId;
    }
    
    public void execute(QueueableContext context) {
        // ── CIRCUIT OPEN ALERT LOG ─────────────────
        NexusIQUtils.log(
            correlationId,
            systemName,
            'FAILED',
            '⚠️ CIRCUIT BREAKER OPEN — ' + systemName + 
            ' is DOWN — Admin Alert! Immediate action required.',
            null,
            null
        );
        NexusIQUtils.flushLogs();
        System.debug('NexusIQ Alert: CB OPEN for ' + systemName);
    }
}