public with sharing class ApexClassTabController {
    
    public ApexClassTabController() {
        //List controllers are not supported for ApexClass
        this.id2class = new Map<Id,ApexClass>();
        this.id2summary = new Map<Id,ApexClassModel.Summary>();
    }
    
    public Map<Id,ApexClass> id2class {get; set;}
    public Map<Id,ApexClassModel.Summary> id2summary {get; set;}
    
    public void doInit() {
        Set<Id> apexClassIds = new Map<Id,SObject>([SELECT Id FROM ApexClass LIMIT 10000]).keySet();
        ApexClassSetModel setModel = ApexClassSetModel.discoverProcesses(apexClassIds);
        
        List<ApexClass> apexClasses = [
            SELECT Id, Name, NamespacePrefix, ApiVersion, Status, IsValid, LastModifiedById, LastModifiedDate
            FROM ApexClass
            WHERE Id IN :setModel.keySet()
        ];
        
        this.id2class = new Map<Id,ApexClass>(apexClasses);
        
        for (ApexClass apexClass : apexClasses) {
            ApexClassModel model = new ApexClassModel(apexClass);
            this.id2summary.put(apexClass.Id, model.esb);
        }
        
        //return models;
    }
}