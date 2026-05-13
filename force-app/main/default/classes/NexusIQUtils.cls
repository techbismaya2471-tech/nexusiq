public class NexusIQUtils {
    
    public static String generateCorrelationId() {
        return 'TXN-' + String.valueOf(DateTime.now().getTime()) + '-' + 
               EncodingUtil.convertToHex(
                   Crypto.generateAesKey(128)
               ).substring(0, 8).toUpperCase();
    }
    
    // SIMPLE LOG — Debug only
    public static void log(String correlationId, String message) {
        System.debug('NexusIQ [' + correlationId + '] : ' + message);
    }
    
    // UNIT OF WORK — Log collector
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
        
        // FIXED — Sirf FAILED logs store karo!
        if(status == 'FAILED') {
            pendingLogs.add(new Integration_Log__c(
                Correlation_Id__c = correlationId,
                System_Name__c    = systemName,
                Status__c         = status,
                Error_Message__c  = message,
                Request_Body__c   = requestBody,
                Response_Body__c  = responseBody != null && responseBody.length() > 2000
                                    ? responseBody.substring(0, 2000) : responseBody
            ));
        }
    }
    
    // FLUSH — Sab logs ek saath insert
    public static void flushLogs() {
        if (!pendingLogs.isEmpty()) {
            insert pendingLogs;
            pendingLogs.clear();
            System.debug('NexusIQ Logs flushed');
        }
    }
}