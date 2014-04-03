public with sharing class SequenceBuilderExtension {
    
    ApexPages.StandardController controller;
    
    public SequenceBuilderExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doRedirect() {
        Integer count = [SELECT COUNT() FROM Process__c];
        if (count > 0) {
            //continue per normal
            return null;
        } else {
            //there are no processes! discover first
            PageReference pr = Page.ProcessDiscover;
            pr.getParameters().put('retURL', ApexPages.currentPage().getUrl());
            return pr;
        }
    }
    
    public String getProcesses() {
        List<Process__c> procs = SalesforceObjectSet.listAll(Process__c.SObjectType);
        return Json.serializePretty(procs);
    }
    
    public String getSteps() {
        Sequence sequence = new Sequence((Sequence__c)this.controller.getRecord());
        List<Step__c> steps = sequence.fetchSteps().getSObjects();
        return Json.serializePretty(steps);
    }
    
    @RemoteAction static public List<Step__c> fetchSteps(Id sequenceId) {
        Sequence sequence = new Sequence(new Sequence__c(Id = sequenceId));
        sequence.terminate();
        return sequence.fetchSteps().getSObjects();
    }
    
    @RemoteAction static public Step__c appendStep(Id sequenceId, Id processId) {
        Sequence sequence = new Sequence(new Sequence__c(Id = sequenceId));
        Step step = sequence.appendStep(processId);
        return (Step__c)step.getSObject();
    }
    
    @RemoteAction static public void moveStepBefore(Id stepId, Id beforeStepId) {
        Step__c step = (Step__c)SalesforceObject.getById(stepId);
        new Step(step).moveBefore(beforeStepId);
    }
    
    @RemoteAction static public void moveStepAfter(Id stepId, Id afterStepId) {
        Step__c step = (Step__c)SalesforceObject.getById(stepId);
        new Step(step).moveAfter(afterStepId);
    }
    
    @RemoteAction static public void destroyStep(Step__c step) {
        step = (Step__c)SalesforceObject.getById(step.Id);
        new Sequence(new Sequence__c(Id = step.Sequence__c)).deleteStep(step.Id);
    }
    
    @RemoteAction static public String enqueue(Id sequenceId) {
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(sequenceId);
        Broker.enqueue(sequence.Name, UserInfo.getUserId());
        return sequence.Name;
    }
}