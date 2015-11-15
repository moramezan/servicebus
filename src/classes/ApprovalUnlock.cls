public class ApprovalUnlock extends ApexClassModel.Service {

    void callout(Map<String,Object> inputEvent) {}
    
    public class ServiceException extends Exception {}
    
    public class Summary extends ApexClassModel.Summary {
        String Tag = 'Service Bus';
        String Label = 'Unlock Record';
        String Description = 'Unlocks record from an approval process.';
        String Icon = 'lock_go';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServiceApprovalUnlock').getUrl();
        Integer Limits = 150; //number of DML allowed
        String Cardinality = 'One';
    }

    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        Id recordId = (Id)inputEvent.get('RecordId');
        if (recordId == null) throw new ServiceException('RecordId parameter is null');

        Approval.Unlock(recordId);
        return new List<Map<String,Object>>{inputEvent};
        
    }

}