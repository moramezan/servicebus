public with sharing class SequenceBuilderExtension {
    
    ApexPages.StandardController controller;
    
    public SequenceBuilderExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public Boolean getCanConfigureRemoteSiteSetting() {
        Profile profile = (Profile)SalesforceObject.getById(UserInfo.getProfileId());
        return profile.PermissionsModifyAllData && profile.PermissionsCustomizeApplication;
    }
    
    public Boolean getIsRemoteSiteSettingPresent() {
        ConfigureController controller = new ConfigureController();
        return controller.getHasRemoteSite();
    }
    
    public String getProcesses() {
        List<Process__c> procs = SalesforceObjectSet.listAll(Process__c.SObjectType);
        return Json.serializePretty(procs);
    }
    
    public String getSteps() {
        SequenceObject sequence = new SequenceObject((Sequence__c)this.controller.getRecord());
        List<Step__c> steps = sequence.fetchSteps().getSObjects();
        return Json.serializePretty(steps);
    }
    
    @RemoteAction static public List<Step__c> fetchSteps(Id sequenceId) {
        SequenceObject sequence = new SequenceObject(new Sequence__c(Id = sequenceId));
        sequence.terminate();
        return sequence.fetchSteps().getSObjects();
    }
    
    @RemoteAction static public Step__c appendStep(Id sequenceId, Id processId) {
        SequenceObject sequence = new SequenceObject(new Sequence__c(Id = sequenceId));
        StepObject step = sequence.appendStep(processId);
        return (Step__c)step.getSObject();
    }
    
    @RemoteAction static public void moveStepBefore(Id stepId, Id beforeStepId) {
        Step__c step = (Step__c)SalesforceObject.getById(stepId);
        new StepObject(step).moveBefore(beforeStepId);
    }
    
    @RemoteAction static public void moveStepAfter(Id stepId, Id afterStepId) {
        Step__c step = (Step__c)SalesforceObject.getById(stepId);
        new StepObject(step).moveAfter(afterStepId);
    }
    
    @RemoteAction static public void destroySteps(List<Step__c> steps) {
        //requery first step to get sequence id, since it is not transmitted
        Step__c step = (Step__c)SalesforceObject.getById(steps[0].Id);
        SequenceObject sequence = new SequenceObject(new Sequence__c(Id = step.Sequence__c));
        sequence.destroySteps(new Map<Id,Step__c>(steps).keySet());
    }
    
    @RemoteAction static public String enqueue(Id sequenceId) {
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(sequenceId);
        Broker.enqueue(sequence.Name, UserInfo.getUserId());
        return sequence.Name;
    }
}