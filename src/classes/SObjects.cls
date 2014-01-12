abstract public class SObjects {
    
    private List<SObject> sobjects;
    
    public List<SObject> getSObjects() {
        return this.sobjects;
    }
    
    public SObjects() {
        this(new List<SObject>());
    }
    
    public SObjects(List<SObject> sobjects) {
        this.sobjects = sobjects;
    }
    
    virtual public void onBeforeInsert(List<SObject> objects) {
        //
    }
    
    virtual public void onAfterInsert(Map<Id,SObject> objects) {
        //
    }
    
    virtual public void onBeforeUpdate(Map<Id,SObject> olds, Map<Id,SObject> news) {
        //
    }
    
    virtual public void onAfterUpdate(Map<Id,SObject> olds, Map<Id,SObject> news) {
        //
    }
    
    virtual public void onBeforeDelete(Map<Id,SObject> objects) {
        //
    }
    
    virtual public void onAfterDelete(Map<Id,SObject> objects) {
        //
    }

}