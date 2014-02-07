abstract public class SalesforceObjects {
    
    private List<SObject> sobjs;
    public List<SObject> getSObjects() {
        return this.sobjs;
    }
    
    public SalesforceObjects(List<SObject> sobjects) {
        this.sobjs = sobjects;
    }
    
    static public List<SObject> fetchAll(SObjectType type) {
        DescribeSObjectResult describe = type.getDescribe();
        String name = describe.getName();
        List<String> fields = new List<String>(describe.fields.getMap().keySet());
        return Database.query('SELECT ' + String.join(fields, ',') + ' FROM ' + name);
    }
}