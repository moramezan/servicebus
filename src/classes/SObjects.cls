abstract public class SObjects {
    
    protected List<SObject> sobjects {get; private set;}
    
    public List<SObject> getSObjects() {
        return this.sobjects;
    }
    
    public SObjects(List<SObject> sobjects) {
        this.sobjects = sobjects;
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