public with sharing class ApexDomain {
    
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
    
    abstract with sharing public class StandardModel {
        
        protected SObject Record;
        public SObject getRecord() {
            if (this.Record.Id != null) {
                return ApexDomain.getById(this.Record.Id);
            } else {
                return this.Record;
            }
        }
        
        public StandardModel(SObject record) {
            this.Record = record;
        }
        
    }
    
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
    
    abstract with sharing public class StandardSetModel {
        
        protected List<SObject> Records;
        public List<SObject> getRecords() {
            return this.Records;
        }
        
        public StandardSetModel(List<SObject> records) {
            this.Records = records;
        }
        
        public Set<Id> keySet() {
            return new Map<Id,SObject>(this.getRecords()).keySet();
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
    
}