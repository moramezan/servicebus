trigger PersistentDataTriggers on PersistentData__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    SObjects sobjects = new PersistentDatas();
    
    if (Trigger.isBefore && Trigger.isInsert) {
        sobjects.onBeforeInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        sobjects.onAfterInsert(Trigger.newMap);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        sobjects.onBeforeUpdate(Trigger.oldMap, Trigger.newMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        sobjects.onAfterUpdate(Trigger.oldMap, Trigger.newMap);
    } else if (Trigger.isBefore && Trigger.isDelete) {
        sobjects.onBeforeDelete(Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isDelete) {
        sobjects.onAfterDelete(Trigger.oldMap);
    }

}