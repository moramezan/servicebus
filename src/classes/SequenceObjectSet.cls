public with sharing class SequenceObjectSet extends SalesforceObjectSet {

    public SequenceObjectSet(List<Sequence__c> sobjects) {
        super(sobjects);
    }
    
    public override void onBeforeDelete() {
        this.cascadeDeletionTriggers();
    }
    
    /**
     * When deleting a MASTER, Salesforce does not fire the DETAIL delete triggers.
     * https://success.salesforce.com/ideaView?id=08730000000BqSJ
     * So we cascade the delete ourselves manually, to make sure they fire.
     */
    @TestVisible private void cascadeDeletionTriggers() {
        Set<Id> sequenceIds = new Map<Id,SObject>(this.getSObjects()).keySet();
        List<Step__c> steps = [
            SELECT Id
            FROM Step__c
            WHERE Sequence__c IN :sequenceIds
        ];
        delete steps;
    }
}