public with sharing class Subscribe implements Process.Plugin {

    public class Meta {
        public SObject ConfigObject = SubscribeConfiguration__c.SObjectType.newSObject();
        public String Icon = 'eye';
        public String DocsPageUrl = Page.SubscribeHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Description = 'Subscribes to a named event';
        result.Tag = 'Event Driven Architecture';
        result.Name = 'Subscribe';
        return result;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        return EdaUtility.convert(new List<Map<String,Object>>{request.inputParameters});
    }
    
    public static List<HealthController.Health> getHealth() {
        List<Sequence__c> sequences = [SELECT id,
                                        Name,
                                        (SELECT id, Name, Process__c, ConfigurationId__c
                                         FROM Steps__r
                                         ORDER BY Position__c ASC) steps
                                 FROM Sequence__c
                                ];
        
        List<Process__c> subscribeProcesses  = [SELECT id, Name
                                                FROM Process__c
                                                WHERE Name = 'Subscribe'
                                               ];
        Process__c subscribeProcess = (subscribeProcesses.size() > 0) ? subscribeProcesses[0] : null;
        Boolean resolvedProcess = (subscribeProcess != null);

        Map<Id,SObject> subscribeConfigurationIdToSubscribeConfiguration = SalesforceObjectSet.mapAll(SubscribeConfiguration__c.SObjectType);
        List<PublishConfiguration__c> publishConfigurations = SalesforceObjectSet.listAll(PublishConfiguration__c.SObjectType);
        Map<Id,SObject> eventTypeIdToEventType = SalesforceObjectSet.mapAll(EventType__c.SObjectType);
        
        List<Map<String,Object>> instanceDetails = new List<Map<String,Object>>();
        for (Sequence__c  sequence : sequences)  {
            String status = resolvedProcess ? 'Ok' : 'Unknown';
            String detail = resolvedProcess ? 'Subscribe Check(s)' : 'Cannot resolve Id of Subscribe process';
            instanceDetails.add(new Map<String,Object>{ 'Status' => status,
                                                        'Detail' => detail,
                                                        'SequenceId' => sequence.Id,
                                                        'SequenceName' => sequence.Name,
                                                        'Steps' => sequence.Steps__r });
        }
        
        if (resolvedProcess) {
            for (Map<String,Object> instanceDetail : instanceDetails) {
                List<Step__c> steps = (List<Step__c>) instanceDetail.get('Steps');
                Integer subscribeOccurs = 0;
                Integer count = 1;
                Boolean subscribeFirst = false;
                Id stepId = null;
                Id subscribeConfigurationId = null;
                for (Step__c step : steps) {
                    if (step.Process__c == SubscribeProcess.Id) {
                        subscribeOccurs++;
                        if (count == 1) {
                            subscribeFirst = true;
                            stepId = step.Id;
                            subscribeConfigurationId = (Id) step.ConfigurationId__c; // cast from string to Id
                        }
                    }
                    count++;
                }
                 
                Boolean hasSubscribe = (subscribeOccurs > 0);
   
                if (hasSubscribe)  {
                    Boolean isError = false;
                    String detail;
                    if (! subscribeFirst) {
                        isError = true;
                        detail = 'Subscribe process not  at front of sequence';
                    }
                    if (subscribeOccurs > 1) {
                        isError = true;
                        detail = 'Subscribe appears more than once in sequence ['+subscribeOccurs+']';
                    }
                    
                    if (isError) {
                        instanceDetail.put('Status', 'Error');
                        instanceDetail.put('Detail', detail);
                    }


                    SubscribeConfiguration__c subscribeConfiguration;
                    Id eventId;
                    if ( !isError ) {
                        subscribeConfiguration = (SubscribeConfiguration__c)subscribeConfigurationIdToSubscribeConfiguration.get(subscribeConfigurationId);
                        if (subscribeConfiguration == null) {
                            isError = true;
                            instanceDetail.put('Status', 'Error');
                            instanceDetail.put('Detail', 'Cannot resolve subscribe configuration');
                        }
                    }
                    if ( !isError ) {
                        eventId = subscribeConfiguration.EventType__c;
                        if (eventId == null) {
                            isError = true;
                            instanceDetail.put('Status', 'Error');
                            instanceDetail.put('Detail', 'No event type defined on subscribe configuration=['+subscribeConfigurationId+']');
                        }
                    }
                    if ( !isError ) {
                        Boolean publisherFound = false;
                        for (PublishConfiguration__c  publishConfiguration :  publishConfigurations) {
                            if (publishConfiguration.EventType__c == eventId) {
                                publisherFound = true;
                            }
                        }
                        if (!publisherFound) {
                            EventType__c eventType = (EventType__c)eventTypeIdToEventType.get(eventId);
                            String eventTypeName  = (eventType == null) ? '' : eventType.Name;
                            instanceDetail.put('Status', 'Warning');
                            instanceDetail.put('Detail', 'No publisher is configured to publish event=['+eventTypeName+']');
                        }
                    }
                }
            }
        }

        system.debug(json.serializePretty(instanceDetails));
        List<HealthController.Health> healths = new List<HealthController.Health>();
        for (Map<String,Object> instanceDetail : instanceDetails) {
            HealthController.Health health = new HealthController.Health();
            health.SequenceId = (Id) instanceDetail.get('SequenceId');
            health.SequenceName = (String) instanceDetail.get('SequenceName');
            health.Detail = (String) instanceDetail.get('Detail');
            health.Status = (String) instanceDetail.get('Status');
            healths.add(health);
        }
          
        return healths;
    }
}