public class ApprovalLock extends ApexClassModel.Service {

    void callout(Map<String,Object> inputEvent) {}
    
    class ServiceException extends Exception {}
    
    public class Summary {
        String Tag = 'Service Bus';
        String Label = 'Lock Record';
        String Description = 'Locks the record, if a qualifying approval process exists.';
        String Icon = 'lock_delete';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServiceApprovalLock').getUrl();
        String Cardinality = 'One';
        @TestVisible Integer Limits = 150; //number of DML allowed
    }

    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        Id recordId = (Id)inputEvent.get('RecordId');
        if (recordId == null) throw new ServiceException('RecordId parameter is null');

        Approval.Lock(recordId);
        return new List<Map<String,Object>>{inputEvent};
        
    }

}