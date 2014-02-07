abstract public class SalesforceObject {
    
    private SObject sobj;
    public SObject getSObject() {
        if (this.sobj.Id != null) {
            return SalesforceObject.getById(this.sobj.Id);
        } else {
            return this.sobj;
        }
    }
    
    public SalesforceObject(SObject sobj) {
        this.sobj = sobj;
    }
    
    //TODO cache describes
    static public SObject getById(Id id) {
        SObjectType type = id.getSObjectType();
        DescribeSObjectResult description = type.getDescribe();
        String name = description.getName();
        String fields = String.join(new List<String>(description.fields.getMap().keySet()), ',');
        return Database.query('SELECT ' + fields + ' FROM ' + name + ' WHERE Id = :id');
    }
}