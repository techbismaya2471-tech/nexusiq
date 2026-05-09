public class TwilioIntegrationService extends NexusIQServiceBase {
    
    private static final String SYSTEM_NAME = 'Twilio';
    private static final String TWILIO_BASE_URL = 'callout:TWILIO_NC';
    
    // ─────────────────────────────────────────────
    // SEND SMS — Order Confirmation
    // ─────────────────────────────────────────────
    public static Map<String, Object> sendSMS(
        String correlationId,
        String to,
        String message,
        String type
    ) {
        if (CircuitBreakerService.isCircuitOpen(SYSTEM_NAME)) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'SMS blocked — Circuit OPEN', '', '');
            return new Map<String, Object>{
                'success' => false,
                'error'   => 'CIRCUIT_OPEN',
                'message' => 'Twilio Circuit Breaker OPEN'
            };
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'correlationId' => correlationId,
            'to'            => to,
            'message'       => message,
            'type'          => type
        };
        String jsonBody = JSON.serialize(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(TWILIO_BASE_URL + '/api/twilio/sms');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        req.setTimeout(10000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            String responseBody = res.getBody();

            if (res.getStatusCode() == 200) {
                CircuitBreakerService.recordSuccess(SYSTEM_NAME);
                NexusIQUtils.log(correlationId, SYSTEM_NAME, 'SUCCESS',
                    'SMS sent successfully', jsonBody, responseBody);
                return (Map<String, Object>)
                    JSON.deserializeUntyped(responseBody);
            } else {
                CircuitBreakerService.recordFailure(SYSTEM_NAME);
                NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                    'SMS failed: ' + res.getStatusCode(),
                    jsonBody, responseBody);
                return new Map<String, Object>{
                    'success' => false,
                    'error'   => 'SMS_FAILED'
                };
            }
        } catch (Exception e) {
            CircuitBreakerService.recordFailure(SYSTEM_NAME);
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                e.getMessage(), jsonBody, '');
            return new Map<String, Object>{
                'success' => false,
                'error'   => 'CALLOUT_EXCEPTION',
                'message' => e.getMessage()
            };
        }
    }

    // ─────────────────────────────────────────────
    // SEND ALERT — Circuit Breaker / Admin
    // ─────────────────────────────────────────────
    public static Map<String, Object> sendAlert(
        String correlationId,
        String to,
        String alertType,
        String systemName,
        String message
    ) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'correlationId' => correlationId,
            'to'            => to,
            'alertType'     => alertType,
            'systemName'    => systemName,
            'message'       => message
        };
        String jsonBody = JSON.serialize(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(TWILIO_BASE_URL + '/api/twilio/alert');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        req.setTimeout(10000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            String responseBody = res.getBody();

            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'SUCCESS',
                'Alert sent: ' + alertType, jsonBody, responseBody);
            return (Map<String, Object>)
                JSON.deserializeUntyped(responseBody);

        } catch (Exception e) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'Alert failed: ' + e.getMessage(), jsonBody, '');
            return new Map<String, Object>{
                'success' => false,
                'error'   => e.getMessage()
            };
        }
    }
}