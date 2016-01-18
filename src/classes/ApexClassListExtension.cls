public with sharing class ApexClassListExtension {
    
    public ApexClassListExtension(ApexPages.StandardController controller) {
        this();
    }
    
    public ApexClassListExtension() {
        //List controllers are not supported for ApexClass
        this.id2class = new Map<Id,ApexClass>();
        this.id2summary = new Map<Id,ApexClassModel.Summary>();
    }
    
    public Map<Id,ApexClass> id2class {get; set;}
    public Map<Id,ApexClassModel.Summary> id2summary {get; set;}
    
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
        
        //for displaying summaries
        Map<String,ApexClassModel.Summary> name2summary = ApexClassSetModel.loadCache();
        for (ApexClassModel.Summary summary : name2summary.values()) this.id2summary.put(summary.Id, summary);
        
        //all ok
        return null;
    }
}