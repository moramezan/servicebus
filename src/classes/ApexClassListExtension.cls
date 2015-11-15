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
    
    public PageReference doRedirect() {
        
        //for displaying classes
        this.id2class = new Map<Id,ApexClass>([
            SELECT Id, Name, NamespacePrefix, ApiVersion, Status, IsValid, LastModifiedById, LastModifiedDate
            FROM ApexClass
            WHERE Name != 'ApexClassModel'
            ORDER BY NamespacePrefix ASC, Name ASC
        ]);
        
        //for displaying summaries
        List<ApexClassModel.Summary> summaries = ApexClassSetModel.loadCache();
        for (ApexClassModel.Summary summary : summaries) this.id2summary.put(summary.Id, summary);
        
        //discover if needed
        return ApexClassDiscoverExtension.DiscoverIfNeeded();
    }
}