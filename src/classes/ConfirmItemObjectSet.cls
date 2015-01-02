public with sharing class ConfirmItemObjectSet extends SalesforceObjectSet {
    
    public ConfirmItemObjectSet(List<ConfirmItem__c> confirmItems) {
        super(confirmItems);
    }
    
    override public void onAfterUpdate(List<SObject> oldObjects) {
        this.handleConfirms();
        this.handleDenies();
    }
    
    @TestVisible private void handleConfirms() {
        List<Message__c> messages = new List<Message__c>();
        List<ConfirmItem__c> confirmItems = this.getSObjects();
        List<Id> idsToDelete = new List<Id>();
        
        //these guys carry on to next step
        for (ConfirmItem__c confirmItem : confirmItems) {
            if (!confirmItem.Confirm__c) continue; //nothing to do
            
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(confirmItem.Parameters__c);
            parameters.put('esb__Confirm', true);
            messages.add(new Message__c(
                Status__c = 'Buffered',
                Parameters__c = Json.serializePretty(parameters)
            ));
            
            idsToDelete.add(confirmItem.Id);
        }
        
        insert messages; //note they will start mid sequence
        Job.process();
        
        Database.delete(idsToDelete);
    }
    
    @TestVisible private void handleDenies() {
        List<Message__c> messages = new List<Message__c>();
        List<ConfirmItem__c> confirmItems = this.getSObjects();
        List<Id> idsToDelete = new List<Id>();
        
        //these guys have no deny sequence and go to hell
        for (ConfirmItem__c confirmItem : confirmItems) {
            if (!confirmItem.Deny__c) continue; //nothing to do
            if (confirmItem.DenySequence__c != null) continue; //nothing to do
            idsToDelete.add(confirmItem.Id);
        }
        
        //gotta get the sequence names
        List<Id> denySequenceIds = new List<Id>();
        for (ConfirmItem__c confirmItem : confirmItems) denySequenceIds.add(confirmItem.DenySequence__c);
        Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([SELECT Id, Name FROM Sequence__c WHERE Id IN :denySequenceIds]);
        
        //these guys have a deny sequence and sent straight there
        for (ConfirmItem__c confirmItem : confirmItems) {
            if (!confirmItem.Deny__c) continue; //nothing to do
            if (confirmItem.DenySequence__c == null) continue; //nothing to do
            
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(confirmItem.Parameters__c);
            parameters.put('esb__Deny', true);
            parameters.put('__SequenceName', id2sequence.get(confirmItem.DenySequence__c).Name);
            parameters.put('__Position', 0);
            messages.add(new Message__c(
                Status__c = 'Buffered',
                Parameters__c = Json.serializePretty(parameters)
            ));
            
            idsToDelete.add(confirmItem.Id);
        }
        
        insert messages; //new guys start mid sequence
        Job.process();
        
        Database.delete(idsToDelete);
    }
    
}