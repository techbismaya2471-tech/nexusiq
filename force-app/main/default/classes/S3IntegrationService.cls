public class S3IntegrationService extends NexusIQServiceBase {
    
    private static final String SYSTEM_NAME = 'S3';
    private static final String S3_BASE_URL = 'callout:S3_NC';
    
    // ─────────────────────────────────────────────
    // UPLOAD FILE
    // ─────────────────────────────────────────────
    public static Map<String, Object> uploadFile(
        String correlationId,
        String fileName,
        String fileType,
        String fileContent,
        String folder
    ) {
        if (CircuitBreakerService.isCircuitOpen(SYSTEM_NAME)) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'Upload blocked — Circuit OPEN', '', '');
            return new Map<String, Object>{
                'success' => false,
                'error'   => 'CIRCUIT_OPEN',
                'message' => 'S3 Circuit Breaker OPEN'
            };
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'correlationId' => correlationId,
            'fileName'      => fileName,
            'fileType'      => fileType,
            'fileContent'   => fileContent,
            'folder'        => folder
        };
        String jsonBody = JSON.serialize(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(S3_BASE_URL + '/api/s3/upload');
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
                    'File uploaded: ' + fileName, jsonBody, responseBody);
                return (Map<String, Object>)
                    JSON.deserializeUntyped(responseBody);
            } else {
                CircuitBreakerService.recordFailure(SYSTEM_NAME);
                NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                    'Upload failed: ' + res.getStatusCode(),
                    jsonBody, responseBody);
                return new Map<String, Object>{
                    'success' => false,
                    'error'   => 'UPLOAD_FAILED'
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
    // GET FILE
    // ─────────────────────────────────────────────
    public static Map<String, Object> getFile(
        String correlationId,
        String fileKey
    ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(S3_BASE_URL + '/api/s3/file?fileKey=' + 
            EncodingUtil.urlEncode(fileKey, 'UTF-8') +
            '&correlationId=' + correlationId);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(10000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            String responseBody = res.getBody();

            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'SUCCESS',
                'File retrieved: ' + fileKey, fileKey, responseBody);
            return (Map<String, Object>)
                JSON.deserializeUntyped(responseBody);

        } catch (Exception e) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                e.getMessage(), fileKey, '');
            return new Map<String, Object>{
                'success' => false,
                'error'   => e.getMessage()
            };
        }
    }

    // ─────────────────────────────────────────────
    // DELETE FILE — SAGA COMPENSATION
    // ─────────────────────────────────────────────
    public static Map<String, Object> deleteFile(
        String correlationId,
        String fileKey
    ) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'correlationId' => correlationId,
            'fileKey'       => fileKey
        };
        String jsonBody = JSON.serialize(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(S3_BASE_URL + '/api/s3/file');
        req.setMethod('DELETE');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        req.setTimeout(10000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            String responseBody = res.getBody();

            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'SUCCESS',
                'File deleted — SAGA compensation', jsonBody, responseBody);
            return (Map<String, Object>)
                JSON.deserializeUntyped(responseBody);

        } catch (Exception e) {
            NexusIQUtils.log(correlationId, SYSTEM_NAME, 'FAILED',
                'Delete failed: ' + e.getMessage(), jsonBody, '');
            return new Map<String, Object>{
                'success' => false,
                'error'   => e.getMessage()
            };
        }
    }
}