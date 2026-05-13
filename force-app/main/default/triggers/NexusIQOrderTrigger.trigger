trigger NexusIQOrderTrigger on NexusIQ_Order__c (after update) {
    for(NexusIQ_Order__c order : Trigger.new) {
        NexusIQ_Order__c oldOrder = Trigger.oldMap.get(order.Id);
        
        if(oldOrder.Status__c != 'Confirmed' 
           && order.Status__c == 'Confirmed') {
            
            // ── CB OPEN CHECK ──────────────────────
            if(CircuitBreakerService.isCircuitOpen('SAP')) {
                NexusIQ_Order__c reject = new NexusIQ_Order__c(
                    Id = order.Id,
                    Status__c = 'Failed',
                    Error_Message__c = 'SAP system is currently DOWN. Please try again later.'
                );
                update reject;
                continue;
            }
            
            // ── DUPLICATE CHECK ────────────────────
            List<NexusIQ_Order__c> existing = [
                SELECT Id FROM NexusIQ_Order__c
                WHERE Customer_Name__c = :order.Customer_Name__c
                AND Item__c = :order.Item__c
                AND Quantity__c = :order.Quantity__c
                AND Status__c IN ('Failed', 'Processing')
                AND Id != :order.Id
                LIMIT 1
            ];
            
            if(!existing.isEmpty()) {
                NexusIQ_Order__c reject = new NexusIQ_Order__c(
                    Id = order.Id,
                    Status__c = 'Failed',
                    Error_Message__c = 'Duplicate order — same item already in retry queue!'
                );
                update reject;
                continue;
            }
            
            // ── PROCESS ORDER ──────────────────────
            System.enqueueJob(new NexusIQOrderQueueable(order));
        }
    }
}