public class NexusIQUtils {
    
    // Generates unique Correlation ID for every transaction
    public static String generateCorrelationId() {
        return 'TXN-' + String.valueOf(DateTime.now().getTime()) + '-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 8).toUpperCase();
    }
    
    // Logs message to debug (can extend to custom object later)
    public static void log(String correlationId, String message) {
        System.debug('NexusIQ [' + correlationId + '] : ' + message);
    }
}