public with sharing class ChainSorterController {
    
    ApexPages.StandardController controller;
    
    public ChainSorterController(ApexPages.StandardController controller) {
        controller.addFields(new List<String>{'Name'});
        this.controller = controller;
    }
    
    public PageReference doRedirect() {
        Integer count = [SELECT COUNT() FROM Process__c];
        if (count > 0) {
            //continue per normal
            return null;
        } else {
            //there are no processes! regenerate first
            PageReference pr = Page.ProcessGenerate;
            pr.getParameters().put('retURL', ApexPages.currentPage().getUrl());
            return pr;
        }
    }
    
    public String getProtocolAndHost() {
        return Url.getSalesforceBaseUrl().toExternalForm();
    }
    
    public String getProcesses() {
        List<Process__c> processes = SalesforceObjects.fetchAll(Process__c.SObjectType);
        return Json.serializePretty(processes);
    }
    
    public String getSteps() {
        Chain chain = new Chain((Chain__c)this.controller.getRecord());
        List<Step__c> steps = chain.fetchSteps().getSObjects();
        return Json.serializePretty(steps);
    }
    
    @RemoteAction static public List<Step__c> fetchSteps(Id chainId) {
        Chain chain = new Chain(new Chain__c(Id = chainId));
        chain.terminate();
        return chain.fetchSteps().getSObjects();
    }
    
    @RemoteAction static public Step__c appendStep(Id chainId, Id processId) {
        Chain chain = new Chain(new Chain__c(Id = chainId));
        Step step = chain.appendStep(processId);
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
        new Chain(new Chain__c(Id = step.Chain__c)).deleteStep(step.Id);
    }
    
    @RemoteAction static public String enqueue(Id chainId) {
        Chain__c chain = [SELECT Name FROM Chain__c WHERE Id = :chainId];
        Broker.enqueue(chain.Name, UserInfo.getUserId());
        return chain.Name;
    }
}