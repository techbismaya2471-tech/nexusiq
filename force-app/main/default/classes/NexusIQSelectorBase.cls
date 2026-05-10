public virtual class NexusIQSelectorBase {
    
    // Get Circuit Breaker record by system name
    public static Circuit_Breaker__c getCircuitBreaker(String systemName) {
        List<Circuit_Breaker__c> records = [
            SELECT Id, System_Name__c, Status__c, 
                   Failure_Count__c, Retry_After__c,
                   Last_Failure_Time__c, Threshold_Count__c,
                   Is_Active__c
            FROM Circuit_Breaker__c
            //WHERE System_Name__c = :systemName
            WHERE  Name= :systemName
            AND Is_Active__c = true
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }
    
    // Get open DLQ records for retry
    public static List<Dead_Letter_Queue__c> getPendingDLQRecords() {
        return [
            SELECT Id, System_Name__c, Payload__c,
                   Retry_Count__c, Max_Retries__c,
                   Next_Retry_Time__c, Correlation_Id__c
            FROM Dead_Letter_Queue__c
            WHERE Status__c = 'PENDING'
            AND Next_Retry_Time__c <= :DateTime.now()
            ORDER BY CreatedDate ASC
            LIMIT 50
        ];
    }
}