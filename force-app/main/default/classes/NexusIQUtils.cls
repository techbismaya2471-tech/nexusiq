public class NexusIQUtils {
    
    public static String generateCorrelationId() {
        return 'TXN-' + String.valueOf(DateTime.now().getTime()) + '-' + 
               EncodingUtil.convertToHex(
                   Crypto.generateAesKey(128)
               ).substring(0, 8).toUpperCase();
    }
    
    public static void log(String correlationId, String message) {
        System.debug('NexusIQ [' + correlationId + '] : ' + message);
    }
    
    public static void log(
        String correlationId,
        String systemName,
        String status,
        String message,
        String requestBody,
        String responseBody
    ) {
        System.debug('NexusIQ [' + correlationId + '] [' + systemName + '] [' + status + '] : ' + message);
        
        Integration_Log__c logRecord = new Integration_Log__c(
            Correlation_Id__c    = correlationId,
            Status__c            = status,
            Error_Message__c     = message,
            Request_Body__c      = requestBody,
            Response_Body__c = responseBody != null && responseBody.length() > 2000
            ? responseBody.substring(0, 2000)
            : responseBody,
            HTTP_Method__c       = systemName
        );
        insert logRecord;
    }
}