public with sharing class NexusIQDashboardController {

    // ── 1. CIRCUIT BREAKER STATUS ──────────────────────
    @AuraEnabled(cacheable=true)
    public static List<CircuitBreakerWrapper> getCircuitBreakerStatus() {
        List<CircuitBreakerWrapper> result = new List<CircuitBreakerWrapper>();
        
        List<Circuit_Breaker__c> cbs = [
            SELECT Id, Name, Status__c, Failure_Count__c,
                   Last_Failure_Time__c, Last_Success_Time__c
            FROM Circuit_Breaker__c
            ORDER BY Name ASC
        ];
        
        for(Circuit_Breaker__c cb : cbs) {
            CircuitBreakerWrapper w = new CircuitBreakerWrapper();
            w.name            = cb.Name;
            w.status          = cb.Status__c;
            w.failureCount    = cb.Failure_Count__c != null ?
                                Integer.valueOf(cb.Failure_Count__c) : 0;
            w.lastFailureTime = cb.Last_Failure_Time__c != null ?
                                cb.Last_Failure_Time__c.format() : 'Never';
            w.lastSuccessTime = cb.Last_Success_Time__c != null ?
                                cb.Last_Success_Time__c.format() : 'Never';
            result.add(w);
        }
        return result;
    }

    // ── 2. INTEGRATION LOGS ────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<IntegrationLogWrapper> getRecentLogs() {
        List<IntegrationLogWrapper> result = new List<IntegrationLogWrapper>();
        
        List<Integration_Log__c> logs = [
            SELECT Id, Name, System_Name__c, HTTP_Method__c,
                   HTTP_Status_Code__c, Status__c, Correlation_Id__c,
                   Error_Message__c, Retry_Count__c, CreatedDate
            FROM Integration_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
        
        for(Integration_Log__c log : logs) {
            IntegrationLogWrapper w = new IntegrationLogWrapper();
            w.name           = log.Name;
            w.systemName     = log.System_Name__c;
            w.httpMethod     = log.HTTP_Method__c;
            w.httpStatusCode = log.HTTP_Status_Code__c != null ?
                               Integer.valueOf(log.HTTP_Status_Code__c) : 0;
            w.status         = log.Status__c;
            w.correlationId  = log.Correlation_Id__c;
            w.errorMessage   = log.Error_Message__c;
            w.retryCount     = log.Retry_Count__c != null ?
                               Integer.valueOf(log.Retry_Count__c) : 0;
            w.createdDate    = log.CreatedDate.format();
            result.add(w);
        }
        return result;
    }

    // ── 3. SAGA TRANSACTIONS ───────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<SagaWrapper> getRecentSagas() {
        List<SagaWrapper> result = new List<SagaWrapper>();
        
        List<SAGA_Transaction__c> sagas = [
            SELECT Id, Name, Status__c, Current_Step__c,
                   Total_Steps__c, Correlation_Id__c,
                   Compensation_Status__c, Error_Message__c,
                   CreatedDate
            FROM SAGA_Transaction__c
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        
        for(SAGA_Transaction__c saga : sagas) {
            SagaWrapper w = new SagaWrapper();
            w.name                = saga.Name;
            w.status              = saga.Status__c;
            w.currentStep         = saga.Current_Step__c != null ?
                                    Integer.valueOf(saga.Current_Step__c) : 0;
            w.totalSteps          = saga.Total_Steps__c != null ?
                                    Integer.valueOf(saga.Total_Steps__c) : 0;
            w.correlationId       = saga.Correlation_Id__c;
            w.compensationStatus  = saga.Compensation_Status__c;
            w.errorMessage        = saga.Error_Message__c;
            w.createdDate         = saga.CreatedDate.format();
            result.add(w);
        }
        return result;
    }

    // ── 4. DASHBOARD SUMMARY ───────────────────────────
    @AuraEnabled(cacheable=true)
    public static DashboardSummaryWrapper getDashboardSummary() {
        DashboardSummaryWrapper w = new DashboardSummaryWrapper();
        
        w.totalLogsToday = [
            SELECT COUNT() FROM Integration_Log__c
            WHERE CreatedDate = TODAY
        ];
        w.successLogsToday = [
            SELECT COUNT() FROM Integration_Log__c
            WHERE CreatedDate = TODAY AND Status__c = 'SUCCESS'
        ];
        w.failedLogsToday = [
            SELECT COUNT() FROM Integration_Log__c
            WHERE CreatedDate = TODAY AND Status__c = 'FAILED'
        ];
        w.activeSagas = [
            SELECT COUNT() FROM SAGA_Transaction__c
            WHERE Status__c = 'RUNNING'
        ];
        w.openCircuits = [
            SELECT COUNT() FROM Circuit_Breaker__c
            WHERE Status__c = 'OPEN'
        ];
        
        return w;
    }

    // ── WRAPPER CLASSES ────────────────────────────────
    public class CircuitBreakerWrapper {
        @AuraEnabled public String  name;
        @AuraEnabled public String  status;
        @AuraEnabled public Integer failureCount;
        @AuraEnabled public String  lastFailureTime;
        @AuraEnabled public String  lastSuccessTime;
    }

    public class IntegrationLogWrapper {
        @AuraEnabled public String  name;
        @AuraEnabled public String  systemName;
        @AuraEnabled public String  httpMethod;
        @AuraEnabled public Integer httpStatusCode;
        @AuraEnabled public String  status;
        @AuraEnabled public String  correlationId;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public Integer retryCount;
        @AuraEnabled public String  createdDate;
    }

    public class SagaWrapper {
        @AuraEnabled public String  name;
        @AuraEnabled public String  status;
        @AuraEnabled public Integer currentStep;
        @AuraEnabled public Integer totalSteps;
        @AuraEnabled public String  correlationId;
        @AuraEnabled public String  compensationStatus;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public String  createdDate;
    }

    public class DashboardSummaryWrapper {
        @AuraEnabled public Integer totalLogsToday;
        @AuraEnabled public Integer successLogsToday;
        @AuraEnabled public Integer failedLogsToday;
        @AuraEnabled public Integer activeSagas;
        @AuraEnabled public Integer openCircuits;
    }
}