public class ApexDomain {
    
    /**
     * Used to advertise errors inside models.
     */
    public class DomainException extends Exception {}
    
    /**
     * Used to enforce read-write permissions
     * for AppExchange security review.
     */
    public class CrudException extends Exception {}
    
    /**
     * Used to enforce field-level permissions
     * for AppExchange security review.
     */
    public class FlsException extends Exception {}
    
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
    }
    
    /**
     * Select all fields on record by id.
     */
    static public SObject getById(Id recordId) {
        if (recordId == null) throw new DomainException('ApexDomain.getById received null recordId.');
        
        SObjectType type = recordId.getSObjectType();
        DescribeSObjectResult description = type.getDescribe();
        String name = description.getName();
        String fields = String.join(new List<String>(description.fields.getMap().keySet()), ',');
        return Database.query('SELECT ' + fields + ' FROM ' + name + ' WHERE Id = :recordId');
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
    
    static public SObject getOne(SObject record) {
        if (record == null) throw new DomainException('ApexDomain.getOne received null record.');
        return getById(record.Id);
    }
    
    static public Boolean exists(Id recordId) {
        if (recordId == null) return false;
        String name = recordId.getSobjectType().getDescribe().getName();
        return !Database.query('SELECT Id FROM ' + name + ' WHERE Id = :recordId').isEmpty();
    }
}