public with sharing class SchemaSelectorController {
    
    /**
     * All four of these URL parameters must be present
     */
    private String objectSchemaKey = ApexPages.currentPage().getParameters().get('objectSchemaKey');
    private String fieldSchemaKey = ApexPages.currentPage().getParameters().get('fieldSchemaKey');
    private String retURL = ApexPages.currentPage().getParameters().get('retURL');
    private String id = ApexPages.currentPage().getParameters().get('id');
    
    public String ObjectName {get; set;}
    public String FieldName {get; set;}
    public List<SelectOption> ObjectNameOptions {get; set;}
    public List<SelectOption> FieldNameOptions {get; set;}
    
    public PageReference doSave() {
        SObject record = SalesforceObject.getById(this.id);
        record.put(this.objectSchemaKey, this.ObjectName);
        record.put(this.fieldSchemaKey, this.FieldName);
        update record;
        return new PageReference(this.retURL);
    }
    
    public PageReference doCancel() {
        SObject record = SalesforceObject.getById(this.id);
        ApexPages.StandardController controller = new ApexPages.StandardController(record);
        return controller.view();
    }
    
    public void doInit() {
        //display object names on first load
        this.populateObjectNameOptions();
    }
    
    public DescribeSObjectResult getDescribe() {
        Id objectId = ApexPages.currentPage().getParameters().get('id');
        SObjectType objectType = objectId.getSObjectType();
        return objectType.getDescribe();
    }
    
    public void populateObjectNameOptions() {
        Map<String,SObjectType> key2type = Schema.getGlobalDescribe();
        List<String> names = new List<String>();
        
        //qualify objects with case-sensitive names
        for (String key : key2type.keySet()) names.add(Type.forName(key).getName());
        names.sort();
        
        //convert list of names to list of selectoptions
        List<SelectOption> options = new List<SelectOption>();
        for (String name : names) options.add(new SelectOption(name, name));
        
        this.objectNameOptions = options;
    }
    
    public void populateFieldNameOptions() {
        Type reflector = Type.forName(this.ObjectName);
        SObject obj = (SObject)reflector.newInstance();
        Set<String> fields = obj.getSObjectType().getDescribe().fields.getMap().keySet();
        
        //prepare dehydrated lowercase object with explicit null values
        Map<String,Object> key2value = new Map<String,Object>();
        for (String field : fields) key2value.put(field, null);
        String data = Json.serialize(key2value);
        
        //hydrate and serialize again to obtain CamelCase field names
        obj = (SObject)Json.deserialize(data, reflector);
        key2value = (Map<String,Object>)Json.deserializeUntyped(Json.serialize(obj));
        key2value.remove('attributes'); //lose "attributes" key
        
        //sorted names
        List<String> names = new List<String>(key2value.keySet());
        names.sort();
        
        //convert names to options
        List<SelectOption> options = new List<SelectOption>();
        for (String name : names) options.add(new SelectOption(name, name));
        this.FieldNameOptions = options;
    }
    
}