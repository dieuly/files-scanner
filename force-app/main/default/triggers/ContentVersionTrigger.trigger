trigger ContentVersionTrigger on ContentVersion (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        ContentVersionTriggerHandler.afterInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        ContentVersionTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
