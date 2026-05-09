public class SAPIntegrationService extends NexusIQServiceBase {
    
    private static final String SYSTEM_NAME = 'SAP';
    private static final String SAP_BASE_URL = 'callout:SAP_NC';
    
    // ─────────────────────────────────────────────
    // STOCK CHECK
    // ─────────────────────────────────────────────
    public static Map<String, Object> checkStock(
        String item, 
        Integer quantity, 
        String correlationId
    ) {
        // Step 1: Circuit Breaker check
        if (CircuitBreakerService.isCircuitOpen(SYSTEM_NAME)) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED', 
                'Stock Check blocked — Circuit OPEN', '', '');
            return new Map<String, Object>{
                'success' => false,
                'error' => 'CIRCUIT_OPEN',
                'message' => 'SAP Circuit Breaker OPEN — request blocked'
            };
        }
        
        // Step 2: HTTP Request banao
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SAP_BASE_URL + '/api/sap/stock-check' +
            '?item=' + item +
            '&quantity=' + quantity +
            '&correlationId=' + correlationId);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(10000);
        
        // Step 3: Call karo
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            String responseBody = res.getBody();
            
            if (res.getStatusCode() == 200) {
                // Success
                CircuitBreakerService.recordSuccess(SYSTEM_NAME);
                NexusIQUtils.log(correlationId, SYSTEM_NAME, 'SUCCESS',
                    'Stock check successful', 
                    'item=' + item + '&qty=' + quantity,
                    responseBody);
                    
                Map<String, Object> result = 
                    (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                return result;
                
            } else {
                // SAP error response
                CircuitBreakerService.recordFailure(SYSTEM_NAME);
                NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                    'SAP returned error: ' + res.getStatusCode(),
                    'item=' + item,
                    responseBody);
                return new Map<String, Object>{
                    'success' => false,
                    'error' => 'SAP_ERROR_' + res.getStatusCode(),
                    'message' => 'SAP returned: ' + res.getStatusCode()
                };
            }
            
        } catch (Exception e) {
            // Network failure
            CircuitBreakerService.recordFailure(SYSTEM_NAME);
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'SAP callout exception: ' + e.getMessage(),
                'item=' + item,
                '');
            return new Map<String, Object>{
                'success' => false,
                'error' => 'CALLOUT_EXCEPTION',
                'message' => e.getMessage()
            };
        }
    }
    
    // ─────────────────────────────────────────────
    // CREATE INVOICE
    // ─────────────────────────────────────────────
    public static Map<String, Object> createInvoice(
        String correlationId,
        String item,
        Integer quantity,
        Decimal amount,
        String customer
    ) {
        if (CircuitBreakerService.isCircuitOpen(SYSTEM_NAME)) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'Invoice blocked — Circuit OPEN', '', '');
            return new Map<String, Object>{
                'success' => false,
                'error' => 'CIRCUIT_OPEN',
                'message' => 'SAP Circuit Breaker OPEN'
            };
        }
        
        // Request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'correlationId' => correlationId,
            'item'          => item,
            'quantity'      => quantity,
            'amount'        => amount,
            'customer'      => customer
        };
        String jsonBody = JSON.serialize(requestBody);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SAP_BASE_URL + '/api/sap/create-invoice');
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
                    'Invoice created', jsonBody, responseBody);
                return (Map<String, Object>) 
                    JSON.deserializeUntyped(responseBody);
            } else {
                CircuitBreakerService.recordFailure(SYSTEM_NAME);
                NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                    'Invoice creation failed: ' + res.getStatusCode(),
                    jsonBody, responseBody);
                return new Map<String, Object>{
                    'success' => false,
                    'error' => 'INVOICE_FAILED'
                };
            }
        } catch (Exception e) {
            CircuitBreakerService.recordFailure(SYSTEM_NAME);
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                e.getMessage(), jsonBody, '');
            return new Map<String, Object>{
                'success' => false,
                'error' => 'CALLOUT_EXCEPTION',
                'message' => e.getMessage()
            };
        }
    }
    
    // ─────────────────────────────────────────────
    // CANCEL INVOICE — SAGA COMPENSATION
    // ─────────────────────────────────────────────
    public static Map<String, Object> cancelInvoice(
        String correlationId,
        String invoiceNumber
    ) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'correlationId' => correlationId,
            'invoiceNumber' => invoiceNumber
        };
        String jsonBody = JSON.serialize(requestBody);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SAP_BASE_URL + '/api/sap/cancel-invoice');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        req.setTimeout(10000);
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            String responseBody = res.getBody();
            
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'SUCCESS',
                'Invoice cancelled — SAGA compensation', 
                jsonBody, responseBody);
                
            return (Map<String, Object>) 
                JSON.deserializeUntyped(responseBody);
                
        } catch (Exception e) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'Cancel invoice failed: ' + e.getMessage(), jsonBody, '');
            return new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage()
            };
        }
    }
}