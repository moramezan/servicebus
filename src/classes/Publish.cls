public with sharing class Publish implements Process.Plugin {
    
    public class PublishException extends Exception {}

    public class Meta {
        public SObject ConfigObject = PublishConfiguration__c.SObjectType.newSObject();
        public String Icon = 'chart_organisation';
        public String DocsPageUrl = Page.PublishConfigurationHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe () {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Description = 'Publishes to a named event type';
        result.Tag = 'Event Driven Architecture';
        result.Name = 'Publish';
        return result;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.InputParameters;
        List<Map<String,Object>> parametersList = new List<Map<string,object>>();
        
        PublishConfiguration__c publishConfiguration = [
            SELECT Id, EventType__c
            FROM PublishConfiguration__c
            WHERE Id = :(Id)parameters.get('eda_ConfigObjectId')
        ];
        
        if (null == publishConfiguration.EventType__c) {
            throw new PublishException('Publish Configuration ' + publishConfiguration.Id + ' has no Event type');
        }
        
        Map<Id,SObject> subscribeConfigurations = new Map<Id,SObject>([
            SELECT Id
            FROM SubscribeConfiguration__c
            WHERE EventType__c = :publishConfiguration.EventType__c
        ]);
        
        List<Step__c> steps = [
            SELECT Id, Sequence__r.Name, Position__c
            FROM Step__c
            WHERE ConfigurationId__c IN :subscribeConfigurations.keySet()
        ];
        
        for (Step__c step : steps) {
            Map<String,Object> clone = parameters.clone();
            //#47: Any messages properties affecting the TERMINATE behaviour should be stripped from FLOW CONTROL
            clone.put('eda_SubsequenceStepIds', null);
            clone.put('eda_Position', step.Position__c);
            clone.put('eda_SequenceName', step.Sequence__r.Name);
            parametersList.add(clone);
        }
        
        //original guy carries on... this is not a Terminate
        parametersList.add(parameters);
        
        return EdaUtility.convert(parametersList);
    }
    
    public static List<HealthController.Health> getHealth() {
        List<Sequence__c> sequences = [
            SELECT id,
            Name,
            (SELECT id, Name, Process__c, ConfigurationId__c
            FROM Steps__r
            ORDER BY Position__c ASC) steps
            FROM Sequence__c
        ];
        
        List<Process__c> publishProcesses = [
            SELECT id, Name
            FROM Process__c
            WHERE Name = 'Publish'
        ];
        
        Process__c publishProcess = (publishProcesses.size() > 0) ? publishProcesses[0] : null;
        Boolean resolvedProcess = (publishProcess != null);

        Map<Id,PublishConfiguration__c> publishConfigurationIdToPublishConfiguration = new Map<Id,PublishConfiguration__c>([
            SELECT id, Name, EventType__c
            FROM PublishConfiguration__c
        ]);

        List<SubscribeConfiguration__c> SubscribeConfigurations = [
            SELECT Id, Name, EventType__c
            FROM SubscribeConfiguration__c
        ];

        Map<Id,EventType__c> eventTypeIdToEventType = new Map<Id,EventType__c>([
            SELECT Id, Name
            FROM EventType__c
        ]);

        List<Map<String,Object>> instanceDetails = new List<Map<String,Object>>();

        for (Sequence__c sequence : sequences) {
            String statusInitial = resolvedProcess ? 'Ok' : 'Unknown';
            String detailInitial = resolvedProcess ? 'Publish Check(s)' : 'Cannot resolve Id of Publish process';
            Map<String,Object> singleInstanceDetail = new Map<String,Object>{
                'Status' => statusInitial,
                'Detail' => detailInitial,
                'SequenceId' => sequence.Id,
                'SequenceName' => sequence.Name,
                'Steps' => sequence.Steps__r
            };

            Boolean requireSingleInstance = false;
            if ( !resolvedProcess ) {
                requireSingleInstance = true;
            }

            if ( resolvedProcess ) {
                Integer publishOccurs = 0;
                for (Step__c step : sequence.Steps__r) {
                    if (step.Process__c == PublishProcess.Id) {
                        publishOccurs++;
                    }
                }
                
                Boolean hasPublish = (publishOccurs > 0);
                
                
                if (hasPublish) {
                    requireSingleInstance = true;
                
                    for (Step__c step : sequence.Steps__r) {
                        if (step.Process__c == PublishProcess.Id) {
                            Id stepId = step.Id;
                            Id publishConfigurationId = (Id) step.ConfigurationId__c; // cast from string to Id
                             
                             String status;
                             String detail;
                             PublishConfiguration__c publishConfiguration;
                             Id eventTypeId;
                             
                             Boolean isOk = true;
                             if ( isOk) {
                                 publishConfiguration = publishConfigurationIdToPublishConfiguration.get(publishConfigurationId);
                                 if (publishConfiguration == null) {
                                     isOk = false;
                                     status = 'Error';
                                     detail = 'Cannot resolve Publish configuration, stepId=['+stepId+']';
                                 }
                             }
                             if ( isOk ) {
                                 eventTypeId = publishConfiguration.EventType__c;
                                 if (eventTypeId == null) {
                                     isOk = false;
                                     status = 'Error';
                                     detail = 'No event type defined on Publish configuration=['+publishConfigurationId+'] for stepId=['+stepId+']';
                                 }
                             }
                             if ( isOk ) {
                                 Boolean subscriberFound = false;
                                 for (SubscribeConfiguration__c SubscribeConfiguration : SubscribeConfigurations) {
                                     if (SubscribeConfiguration.EventType__c == eventTypeId) {
                                         subscriberFound = true;
                                     }
                                 }
                                 if (!subscriberFound) {
                                     isOk = false;
                                     EventType__c eventType = eventTypeIdToEventType.get(eventTypeId);
                                     String eventTypeName = (eventType == null) ? '' : eventType.Name;
                                     isOk = false;
                                     status = 'Warning';
                                     detail = 'No Subscriber is configured to subscribe to event=['+eventTypeName+'] published on stepId=['+stepId+']';
                                 }
                             }

                            if ( !isOk ) {
                                requireSingleInstance = false;
                                instanceDetails.add(new Map<String,Object>{
                                    'Status' => status,
                                    'Detail' => detail,
                                    'SequenceId' => sequence.Id,
                                    'SequenceName' => sequence.Name,
                                    'Steps' => sequence.Steps__r
                                });
                            }
                        } // end: if (step.Process__c == PublishProcess.Id)
                    } // end:: for (Step__c step : sequence.Steps__r)
                } // end:: if (hasPublish)
            } // end: if ( resolvedProcess )

            if (requireSingleInstance) {
                instanceDetails.add(singleInstanceDetail);
            }
        } // end: for (Sequence__c sequence : sequences)
             
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