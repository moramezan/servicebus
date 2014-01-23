public with sharing class ChainSorterController {
    
    ApexPages.StandardController controller;
    
    public ChainSorterController(ApexPages.StandardController controller) {
        controller.addFields(new List<String>{'Name'});
        this.controller = controller;
    }
    
    public String getProtocolAndHost() {
        return Url.getSalesforceBaseUrl().toExternalForm();
    }
    
    public String getProcesses() {
        List<Process__c> processes = [
            SELECT Id, Name, Tag__c, Icon__c
            FROM Process__c
            ORDER BY Name ASC
        ];
        return Json.serializePretty(processes);
    }
    
    @RemoteAction static public List<ChainStep__c> readChainSteps(Id chainId) {
        return [
            SELECT Id, Name, Chain__c, Sequence__c, Process__r.Name, Process__r.Description__c
            FROM ChainStep__c
            WHERE Chain__c = :chainId
            ORDER BY Sequence__c
        ];
    }
    
    @RemoteAction static public List<ChainStep__c> updateChainSteps(List<ChainStep__c> chainSteps) {
        update chainSteps;
        return chainSteps;
    }
    
    @RemoteAction static public void destroyChainSteps(List<ChainStep__c> stepsToDelete) {
        //first get a handle on the chain whose steps will reorder afterwards
        Id chainId = [
            SELECT Chain__c
            FROM ChainStep__c
            WHERE Id = :stepsToDelete[0].Id
        ].Chain__c;
        
        //delete the intended steps
        delete stepsToDelete;
        
        List<ChainStep__c> stepsToReorder = [
            SELECT Id
            FROM ChainStep__c
            WHERE Chain__c = :chainId
            ORDER BY Sequence__c
        ];
        
        Integer sequence = 1;
        for (ChainStep__c chainStep : stepsToReorder) {
            chainStep.Sequence__c = sequence++;
        }
        
        update stepsToReorder;
    }
    
    @RemoteAction static public String enqueue(Id chainId) {
        Chain__c chain = [SELECT Name FROM Chain__c WHERE Id = :chainId];
        new ProxyBroker().enqueue(chain.Name, UserInfo.getUserId());
        return chain.Name;
    }
    
    @RemoteAction static public ChainStep__c newStep(Id chainId, Id processId) {
        ChainStep__c chainStep = new ChainStep__c(
            Chain__c = chainId,
            Process__c = processId
        );
        
        insert chainStep;
        
        chainStep = [
            SELECT Id, Name, Sequence__c, Configuration__c, Process__c, Chain__c
            FROM ChainStep__c
            WHERE Id = :chainStep.Id
        ];
        
        return chainStep;
    }
    
}