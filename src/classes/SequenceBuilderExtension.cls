public with sharing class SequenceBuilderExtension {
    
    ApexPages.StandardController controller;
    
    public SequenceBuilderExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doRedirect() {
        PageReference pr;
        
        //first confirm the remote site setting exists
        ConfigureController controller = new ConfigureController();
        pr = controller.doRedirect();
        if (pr != null) return pr;
        
        //then check if process discovery needs to run
        pr = Page.ProcessDiscover;
        pr.getParameters().put('retURL', ApexPages.currentPage().getUrl());
        Integer count = [SELECT COUNT() FROM Process__c WHERE FullyQualifiedClassName__c = :Terminate.class.getName()];
        if (count == 0) return pr;
        
        //all systems go
        return null;
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
    
    @RemoteAction static public void destroySteps(List<Step__c> steps) {
        //requery first step to get sequence id, since it is not transmitted
        Step__c step = (Step__c)SalesforceObject.getById(steps[0].Id);
        Sequence sequence = new Sequence(new Sequence__c(Id = step.Sequence__c));
        sequence.destroySteps(new Map<Id,Step__c>(steps).keySet());
    }
    
    @RemoteAction static public String enqueue(Id sequenceId) {
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(sequenceId);
        Broker.enqueue(sequence.Name, UserInfo.getUserId());
        return sequence.Name;
    }
}