public class NexusIQUtils {
    
    // ─────────────────────────────────────
    // CORRELATION ID
    // ─────────────────────────────────────
    public static String generateCorrelationId() {
        return 'TXN-' + String.valueOf(DateTime.now().getTime()) + '-' + 
               EncodingUtil.convertToHex(
                   Crypto.generateAesKey(128)
               ).substring(0, 8).toUpperCase();
    }
    
    // ─────────────────────────────────────
    // SIMPLE LOG — Debug only
    // ─────────────────────────────────────
    public static void log(String correlationId, String message) {
        System.debug('NexusIQ [' + correlationId + '] : ' + message);
    }
    
    // ─────────────────────────────────────
    // UNIT OF WORK — Log collector
    // ─────────────────────────────────────
    // In-memory log list — callouts ke baad flush karenge
    private static List<Integration_Log__c> pendingLogs = new List<Integration_Log__c>();
    
    public static void log(
        String correlationId,
        String systemName,
        String status,
        String message,
        String requestBody,
        String responseBody
    ) {
        System.debug('NexusIQ [' + correlationId + '] [' + systemName + '] [' + status + '] : ' + message);
        
        // Log collect karo — insert nahi karo abhi
        pendingLogs.add(new Integration_Log__c(
            Correlation_Id__c = correlationId,
            Status__c         = status,
            Error_Message__c  = message,
            Request_Body__c   = requestBody,
            Response_Body__c  = responseBody != null && responseBody.length() > 2000
                                ? responseBody.substring(0, 2000) : responseBody,
            HTTP_Method__c    = systemName
        ));
    }
    
    // ─────────────────────────────────────
    // FLUSH — Sab logs ek saath insert
    // Call karo jab saare callouts complete hon
    // ─────────────────────────────────────
    public static void flushLogs() {
        if (!pendingLogs.isEmpty()) {
            insert pendingLogs;
            pendingLogs.clear();
            System.debug('NexusIQ Logs flushed: ' + pendingLogs.size() + ' records');
        }
    }
}