public class ApexDomain {
    
    /**
     * Used to advertise errors inside models.
     */
    public class DomainException extends Exception {}
    
    /**
     * Used to enforce read-write permissions
     * for AppExchange security review.
     */
    
    /**
     * Used to enforce field-level permissions
     * for AppExchange security review.
     */
    
    /**
     * Domain layer base class for
     * dealing with single records
     */
    abstract public class StandardModel {
        
        protected SObject Record;
        
        public SObject getRecord() {
            return this.Record;
        }
        
        public Id getId() {
            return this.Record.Id;
        }
        
        public StandardModel(SObject record) {
            this.Record = record;
        }
    }
    
    /**
     * Domain layer base class for
     * dealing with collections
     */
    abstract public class StandardSetModel {
        
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
        
        virtual public void onBeforeInsert() {}
        virtual public void onAfterInsert() {}
        virtual public void onBeforeUpdate(List<SObject> oldRecords) {}
        virtual public void onAfterUpdate(List<SObject> oldRecords) {}
        virtual public void onBeforeDelete() {}
        virtual public void onAfterDelete() {}
        virtual public void onAfterUndelete() {}
    }
    
    @TestVisible static Map<Id,SObject> id2mock = new Map<Id,SObject>();
    
    @TestVisible static void setById(Id recordId, SObject mock) {
        id2mock.put(recordId, mock);
    }
    
    /**
     * Select all fields on record by id.
     */
    static public SObject getById(Id recordId) {
        
        if (recordId == null) {
            //failure, cant find null id
            throw new DomainException('Id argument is null.');
        }
        
        if (Test.isRunningTest() && id2mock.containsKey(recordId)) {
            //mockable records in tests
            return id2mock.get(recordId);
        }
        
        try {
            SObjectType type = recordId.getSObjectType();
            DescribeSObjectResult description = type.getDescribe();
            String name = description.getName();
            String fields = String.join(new List<String>(description.fields.getMap().keySet()), ',');
            return Database.query('SELECT ' + fields + ' FROM ' + name + ' WHERE Id = :recordId ALL ROWS');
            
        } catch (Exception e) {
            //failure, bad describe, non existent etc
            throw new DomainException('Cannot query "' + recordId + '" ' + e.getMessage());
        }
    }
    
    static public List<SObject> get(List<SObject> records) {
        if (records.isEmpty()) return new List<SObject>();
        
        //assemble all the ids in order
        List<Id> recordIds = new List<Id>();
        for (SObject record : records) recordIds.add(record.Id);
        
        //use the ids to fetch fully hydrated records
        SObjectType type = new List<Id>(recordIds)[0].getSObjectType();
        DescribeSObjectResult description = type.getDescribe();
        String name = description.getName();
        String fields = String.join(new List<String>(description.fields.getMap().keySet()), ',');
        List<SObject> unorderedResults = Database.query('SELECT ' + fields + ' FROM ' + name + ' WHERE Id IN :recordIds');
        
        //manually re-key the sort order that was lost by the requery
        Map<Id,SObject> id2result = new Map<Id,SObject>(unorderedResults);
        List<SObject> orderedResults = new List<SObject>();
        for (Id recordId : recordIds) orderedResults.add(id2result.get(recordId));
        
        return orderedResults;
    }
    
    static public Boolean exists(Id recordId) {
        if (recordId == null) return false;
        String name = recordId.getSobjectType().getDescribe().getName();
        return !Database.query('SELECT Id FROM ' + name + ' WHERE Id = :recordId').isEmpty();
    }
    
    static public void crudFls(Boolean able) {
        //TODO should this behave differently in unit tests?
        DomainException e = new DomainException('CRUD/FLS check failed.');
        e.setMessage(e.getMessage() + ': ' + e.getStackTraceString());
        if (!able) throw e;
    }
}