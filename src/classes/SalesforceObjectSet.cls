abstract public class SalesforceObjectSet {
    
    private List<SObject> sobjs;
    public List<SObject> getSObjects() {
        return this.sobjs;
    }
    
    public SalesforceObjectSet(List<SObject> sobjects) {
        this.sobjs = sobjects;
    }
    
    static public List<SObject> fetchAll(SObjectType type) {
        DescribeSObjectResult describe = type.getDescribe();
        String name = describe.getName();
        List<String> fields = new List<String>(describe.fields.getMap().keySet());
        return Database.query('SELECT ' + String.join(fields, ',') + ' FROM ' + name);
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