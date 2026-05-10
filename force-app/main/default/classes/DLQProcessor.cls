public class DLQProcessor implements Schedulable, Database.Batchable<sObject> {

    // ── SCHEDULABLE — Har 5 min mein run hoga ─────────
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new DLQProcessor(), 10);
    }

    // ── BATCH START — Process karne layak records lo ──
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime now = DateTime.now();
        return Database.getQueryLocator([
            SELECT Id, Name, System_Name__c, Payload__c,
                   Retry_Count__c, Max_Retries__c,
                   Next_Retry_Time__c, Error_Message__c,
                   Correlation_Id__c, Status__c
            FROM Dead_Letter_Queue__c
            WHERE Status__c = 'PENDING'
            AND Next_Retry_Time__c <= :now
            ORDER BY Next_Retry_Time__c ASC
        ]);
    }

    // ── BATCH EXECUTE — Har record ko retry karo ──────
    public void execute(Database.BatchableContext bc, 
                        List<Dead_Letter_Queue__c> dlqRecords) {
        List<Dead_Letter_Queue__c> toUpdate = new List<Dead_Letter_Queue__c>();

        for(Dead_Letter_Queue__c dlq : dlqRecords) {
            Integer retryCount = dlq.Retry_Count__c != null ? 
                                 Integer.valueOf(dlq.Retry_Count__c) : 0;
            Integer maxRetries = dlq.Max_Retries__c != null ? 
                                 Integer.valueOf(dlq.Max_Retries__c) : 3;

            try {
                // Retry attempt
                Boolean success = retryCallout(dlq);

                if(success) {
                    // SUCCESS — DLQ resolve karo
                    dlq.Status__c     = 'RESOLVED';
                    dlq.Resolved_At__c = DateTime.now();
                    NexusIQUtils.log(
                                    dlq.Correlation_Id__c,
                                    dlq.System_Name__c,
                                    'SUCCESS',
                                    'DLQ retry succeeded',
                                    null,
                                    null
                                );
                } else {
                    // FAILED — retry count badhao
                    retryCount++;
                    dlq.Retry_Count__c = retryCount;

                    if(retryCount >= maxRetries) {
                        // Max retries reached — DEAD
                        dlq.Status__c      = 'DEAD';
                        dlq.Error_Message__c = 'Max retries (' + maxRetries + 
                                              ') reached. Permanently failed.';
                        NexusIQUtils.log(
                                    dlq.Correlation_Id__c,
                                    dlq.System_Name__c,
                                    'FAILED',
                                    dlq.Error_Message__c,
                                    null,
                                    null
                                );
                    } else {
                        // Exponential backoff — next retry time calculate karo
                        dlq.Status__c          = 'PENDING';
                        dlq.Next_Retry_Time__c = calculateNextRetry(retryCount);
                        dlq.Error_Message__c   = 'Retry ' + retryCount + 
                                                '/' + maxRetries + ' failed.';
                    }
                }
            } catch(Exception e) {
                retryCount++;
                dlq.Retry_Count__c   = retryCount;
                dlq.Error_Message__c = e.getMessage();

                if(retryCount >= maxRetries) {
                    dlq.Status__c = 'DEAD';
                } else {
                    dlq.Status__c          = 'PENDING';
                    dlq.Next_Retry_Time__c = calculateNextRetry(retryCount);
                }
            }

            toUpdate.add(dlq);
        }

        if(!toUpdate.isEmpty()) {
            update toUpdate;
            NexusIQUtils.flushLogs();
        }
    }

    // ── BATCH FINISH ───────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug('DLQProcessor batch complete.');
    }

    // ── EXPONENTIAL BACKOFF CALCULATOR ─────────────────
    // Retry 1 → 2 min
    // Retry 2 → 4 min
    // Retry 3 → 8 min (max)
    private DateTime calculateNextRetry(Integer retryCount) {
        Integer baseMinutes = 2;
        Integer waitMinutes = (Integer) Math.pow(2, retryCount - 1) * baseMinutes;
        waitMinutes = Math.min(waitMinutes, 480); // Max 8 hours
        return DateTime.now().addMinutes(waitMinutes);
    }

    // ── ACTUAL RETRY CALLOUT ───────────────────────────
    private Boolean retryCallout(Dead_Letter_Queue__c dlq) {
        try {
            String sys = dlq.System_Name__c;

            if(sys == 'SAP') {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:SAP_NC/api/sap/health');
                req.setMethod('GET');
                req.setTimeout(10000);
                HttpResponse res = new Http().send(req);
                return res.getStatusCode() == 200;

            } else if(sys == 'Stripe') {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:STRIPE_NC/api/stripe/health');
                req.setMethod('GET');
                req.setTimeout(10000);
                HttpResponse res = new Http().send(req);
                return res.getStatusCode() == 200;

            } else if(sys == 'Twilio') {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:TWILIO_NC/api/twilio/health');
                req.setMethod('GET');
                req.setTimeout(10000);
                HttpResponse res = new Http().send(req);
                return res.getStatusCode() == 200;

            } else if(sys == 'S3') {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:S3_NC/api/s3/health');
                req.setMethod('GET');
                req.setTimeout(10000);
                HttpResponse res = new Http().send(req);
                return res.getStatusCode() == 200;
            }

            return false;
        } catch(Exception e) {
            return false;
        }
    }

    // ── STATIC HELPER — DLQ mein add karo ─────────────
    public static void addToDLQ(String systemName, 
                                 String payload,
                                 String errorMessage, 
                                 String correlationId) {
        Dead_Letter_Queue__c dlq = new Dead_Letter_Queue__c();
        dlq.System_Name__c     = systemName;
        dlq.Payload__c         = payload;
        dlq.Error_Message__c   = errorMessage;
        dlq.Correlation_Id__c  = correlationId;
        dlq.Status__c          = 'PENDING';
        dlq.Retry_Count__c     = 0;
        dlq.Max_Retries__c     = 3;
        dlq.Next_Retry_Time__c = DateTime.now().addMinutes(2);
        insert dlq;
    }
}