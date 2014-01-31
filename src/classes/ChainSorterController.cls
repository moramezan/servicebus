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
    
    public String getChainSteps() {
        Chain chain = new Chain((Chain__c)this.controller.getRecord());
        List<ChainStep__c> chainSteps = chain.fetchSteps().getSObjects();
        return Json.serializePretty(chainSteps);
    }
    
    @RemoteAction static public List<ChainStep__c> fetchChainSteps(Id chainId) {
        ChainSteps chainSteps = new Chain(new Chain__c(Id = chainId)).fetchSteps();
        return chainSteps.getSObjects();
    }
    
    @RemoteAction static public ChainStep__c appendStep(Id chainId, Id processId) {
        Chain chain = new Chain(new Chain__c(Id = chainId));
        ChainStep step = chain.appendStep(processId);
        return (ChainStep__c)step.getSObject();
    }
    
    @RemoteAction static public void moveChainStepBefore(Id chainStepId, Id beforeStepId) {
        ChainStep__c chainStep = (ChainStep__c)SalesforceObject.getById(chainStepId);
        new ChainStep(chainStep).moveBefore(beforeStepId);
    }
    
    @RemoteAction static public void moveChainStepAfter(Id chainStepId, Id afterStepId) {
        ChainStep__c chainStep = (ChainStep__c)SalesforceObject.getById(chainStepId);
        new ChainStep(chainStep).moveAfter(afterStepId);
    }
    
    @RemoteAction static public void destroyChainStep(ChainStep__c chainStep) {
        chainStep = (ChainStep__c)SalesforceObject.getById(chainStep.Id);
        new Chain(new Chain__c(Id = chainStep.Chain__c)).deleteStep(chainStep.Id);
    }
    
    @RemoteAction static public String enqueue(Id chainId) {
        Chain__c chain = [SELECT Name FROM Chain__c WHERE Id = :chainId];
        Broker.enqueue(chain.Name, UserInfo.getUserId());
        return chain.Name;
    }
}