abstract with sharing public class SalesforceObject {
    
    /**
     * Used to enforce read-write permissions
     * for AppExchange security review process.
     */
    public class CrudException extends Exception {}
    
    /**
     * Used to enforce field-level permissions
     * for AppExchange security review process.
     */
    public class FlsException extends Exception {}
    
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
    
    static public List<SObject> getByIds(List<Id> ids) {
        if (ids.isEmpty()) return new List<SObject>();
        
        SObjectType type = ids[0].getSObjectType();
        DescribeSObjectResult description = type.getDescribe();
        String name = description.getName();
        String fields = String.join(new List<String>(description.fields.getMap().keySet()), ',');
        return Database.query('SELECT ' + fields + ' FROM ' + name + ' WHERE Id IN :ids');
    }

}