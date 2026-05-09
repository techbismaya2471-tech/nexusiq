public class StripeIntegrationService extends NexusIQServiceBase {
    
    private static final String SYSTEM_NAME = 'Stripe';
    private static final String STRIPE_BASE_URL = 'callout:STRIPE_NC';
    
    // ─────────────────────────────────────────────
    // CHARGE PAYMENT
    // ─────────────────────────────────────────────
    public static Map<String, Object> chargePayment(
        String correlationId,
        Decimal amount,
        String customer,
        String description
    ) {
        if (CircuitBreakerService.isCircuitOpen(SYSTEM_NAME)) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'Payment blocked — Circuit OPEN', '', '');
            return new Map<String, Object>{
                'success' => false,
                'error' => 'CIRCUIT_OPEN',
                'message' => 'Stripe Circuit Breaker OPEN'
            };
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'correlationId' => correlationId,
            'amount'        => amount,
            'currency'      => 'inr',
            'customer'      => customer,
            'description'   => description
        };
        String jsonBody = JSON.serialize(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(STRIPE_BASE_URL + '/api/stripe/charge');
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
                    'Payment successful', jsonBody, responseBody);
                return (Map<String, Object>)
                    JSON.deserializeUntyped(responseBody);
            } else {
                CircuitBreakerService.recordFailure(SYSTEM_NAME);
                NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                    'Payment failed: ' + res.getStatusCode(),
                    jsonBody, responseBody);
                return new Map<String, Object>{
                    'success' => false,
                    'error'   => 'PAYMENT_FAILED',
                    'message' => 'Stripe returned: ' + res.getStatusCode()
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
    // REFUND — SAGA COMPENSATION
    // ─────────────────────────────────────────────
    public static Map<String, Object> refundPayment(
        String correlationId,
        String chargeId,
        Decimal amount
    ) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'correlationId' => correlationId,
            'chargeId'      => chargeId,
            'amount'        => amount
        };
        String jsonBody = JSON.serialize(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(STRIPE_BASE_URL + '/api/stripe/refund');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        req.setTimeout(10000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            String responseBody = res.getBody();

            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'SUCCESS',
                'Refund successful — SAGA compensation',
                jsonBody, responseBody);
            return (Map<String, Object>)
                JSON.deserializeUntyped(responseBody);

        } catch (Exception e) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'Refund failed: ' + e.getMessage(), jsonBody, '');
            return new Map<String, Object>{
                'success' => false,
                'error'   => e.getMessage()
            };
        }
    }

    // ─────────────────────────────────────────────
    // PAYMENT STATUS CHECK
    // ─────────────────────────────────────────────
    public static Map<String, Object> checkPaymentStatus(
        String correlationId,
        String chargeId
    ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(STRIPE_BASE_URL + '/api/stripe/status/' + chargeId +
            '?correlationId=' + correlationId);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(10000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            String responseBody = res.getBody();

            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'SUCCESS',
                'Payment status checked', chargeId, responseBody);
            return (Map<String, Object>)
                JSON.deserializeUntyped(responseBody);

        } catch (Exception e) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                e.getMessage(), chargeId, '');
            return new Map<String, Object>{
                'success' => false,
                'error'   => e.getMessage()
            };
        }
    }
}