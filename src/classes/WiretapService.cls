public class WiretapService extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    public class Definition extends ApexClassModel.Definition {
        String Tag = 'Services';
        String Label = 'Wiretap';
        String Description = 'Emails the message parameters to the user.';
        String ServiceConfig = WiretapServiceConfig__c.class.getName();
        String Icon = 'email';
        Integer Chunks = 5; //leave half of 10 (Total number of sendEmail methods allowed)
        String Cardinality = 'One';
    }
    
    List<Map<String,Object>> execute(Map<String,Object> parameters) {
        
        WiretapServiceConfig__c wiretapServiceConfig = WiretapServiceConfig__c.getOrgDefaults();
        Id userId = wiretapServiceConfig.UserId__c;
        if (userId == null) {
            userId = UserInfo.getUserId();
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSubject('[Wiretap] '
            + UserInfo.getUserId()
            + '@'
            + UserInfo.getOrganizationId()
            + ' '
            + parameters.get('Route')
        );
        
        String body = '';
        
        //#1022 show RecordId list from gated messages
        if (parameters.containsKey('AggregateQuery') && parameters.containsKey('AggregateField')) {
            List<String> recordIds = new List<String>();
            
            String query = (String)parameters.get('AggregateQuery');
            String field = (String)parameters.get('AggregateField');
            List<SObject> items = Database.query(query);
            
            for (SObject item : items) {
                String data = (String)item.get(field);
                Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(data);
                String recordId = (String)event.get('RecordId');
                recordIds.add(recordId);
            }
            
            body += 'Gated Record Ids:\n';
            body += Json.serializePretty(recordIds) + '\n\n';
        }
        
        body += 'Event parameters:\n';
        body += new MessageSetModel.SortedSerializer(parameters).toString();
        
        message.setPlainTextBody(body);
        message.setTargetObjectId(userId);
        message.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
        
        return new List<Map<String,Object>>{parameters};
    }
}