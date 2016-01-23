public with sharing class ApexClassListExtension {
    
    public ApexClassListExtension(ApexPages.StandardController controller) {
        this();
    }
    
    public ApexClassListExtension() {
        //List controllers are not supported for ApexClass
        this.id2class = new Map<Id,ApexClass>();
        this.id2definition = new Map<Id,ApexClassModel.Definition>();
    }
    
    public Map<Id,ApexClass> id2class {get; set;}
    public Map<Id,ApexClassModel.Definition> id2definition {get; set;}
    
    public User getRunAsUser() {
        return [
            SELECT Id, Name
            FROM User
            WHERE Id = :Application__c.getOrgDefaults().RunAsUserId__c
        ];
    }
    
    public PageReference doRedirect() {
        PageReference redirect;
        
        //configure if needed
        redirect = ConfigureController.ConfigureIfNeeded(ApexPages.currentPage());
        if (redirect != null) return redirect;
        
        //discover if needed
        redirect = ApexClassDiscoverExtension.DiscoverIfNeeded(ApexPages.currentPage());
        if (redirect != null) return redirect;
        
        //for displaying classes
        this.id2class = new Map<Id,ApexClass>([
            SELECT Id, Name, NamespacePrefix, ApiVersion, Status, IsValid, LastModifiedById, LastModifiedDate
            FROM ApexClass
            WHERE Name != 'ApexClassModel'
            ORDER BY NamespacePrefix ASC, Name ASC
        ]);
        
        //for displaying definitions
        Map<String,ApexClassModel.Definition> name2definition = ApexClassSetModel.loadCache();
        for (ApexClassModel.Definition definition : name2definition.values()) this.id2definition.put(definition.Id, definition);
        
        //all ok
        return null;
    }
}