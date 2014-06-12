abstract with sharing public class SalesforceObjectSet {
    
    private List<SObject> sobjs;
    public List<SObject> getSObjects() {
        return this.sobjs;
    }
    
    public SalesforceObjectSet(List<SObject> sobjects) {
        this.sobjs = sobjects;
    }
    
    static public List<SObject> listAll(SObjectType type) {
        DescribeSObjectResult description = type.getDescribe();
        String name = description.getName();
        String fields = String.join(new List<String>(description.fields.getMap().keySet()), ',');
        return Database.query('SELECT ' + fields + ' FROM ' + name + ' ORDER BY Name ASC');
    }
    
    static public Map<Id,SObject> mapAll(SObjectType type) {
        List<SObject> objects = listAll(type);
        return new Map<Id,SObject>(objects);
    }
    
    public Set<Id> keySet() {
        return new Map<Id,SObject>(this.getSObjects()).keySet();
    }
    
    virtual public void onBeforeInsert() {
        //
    }
    
    virtual public void onAfterInsert() {
        //
    }
    
    virtual public void onBeforeUpdate(List<SObject> oldObjects) {
        //
    }
    
    virtual public void onAfterUpdate(List<SObject> oldObjects) {
        //
    }
    
    virtual public void onBeforeDelete() {
        //
    }
    
    virtual public void onAfterDelete() {
        //
    }
}