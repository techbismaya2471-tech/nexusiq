trigger NexusIQOrderTrigger on NexusIQ_Order__c (after update) {
    for(NexusIQ_Order__c order : Trigger.new) {
        NexusIQ_Order__c oldOrder = Trigger.oldMap.get(order.Id);
        
        if(oldOrder.Status__c != 'Confirmed' 
           && order.Status__c == 'Confirmed') {
            System.enqueueJob(new NexusIQOrderQueueable(order));
        }
    }
}