public with sharing class Subscribe implements Process.Plugin, Database.Stateful {

    public class Metadata {
        public SObject configurable = SubscribeConfiguration__c.SObjectType.newSObject();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Description = 'Subscribes to a named event';
        result.Tag = 'Event Driven Architecture';
        return result;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        return Utility.convert(new List<Map<String,Object>>{request.inputParameters});
    }
    
    public static List<HealthController.Health> getHealth() {
        List<Chain__c> chains = [SELECT id, 
                                        Name, 
                                        (SELECT id, Name, Process__c, Configuration__c
                                         FROM ChainSteps__r 
                                         ORDER BY Sequence__c ASC) chainSteps  
                                 FROM Chain__c
                                ];
        
        List<Process__c> subscribeProcesses  = [SELECT id, Name 
                                                FROM Process__c 
                                                WHERE Name = 'Subscribe'
                                               ];
        Process__c subscribeProcess = (subscribeProcesses.size() > 0) ? subscribeProcesses[0] : null; 
        Boolean resolvedProcess = (subscribeProcess != null);                

     
        Map<Id,SubscribeConfiguration__c> subscribeConfigurationIdToSubscribeConfiguration  
                = new Map<Id,SubscribeConfiguration__c>([SELECT id, Name, Event__c  
                                                         FROM SubscribeConfiguration__c    
                                                        ]);

        List<PublishConfiguration__c> publishConfigurations = [SELECT Id, Name, Event__c 
                                                             FROM PublishConfiguration__c    
                                                             ];
                    
        Map<Id,Event__c> eventIdToEvent = new Map<Id,Event__c>([SELECT Id, Name 
                                                                FROM Event__c    
                                                               ]);                                                
               
                           
        List<Map<String,Object>> instanceDetails = new List<Map<String,Object>>();
        for (Chain__c  chain : chains)  {
            String status = resolvedProcess ? 'Ok' : 'Unknown';
            String detail = resolvedProcess ? 'Subscribe Check(s)' : 'Cannot resolve Id of Subscribe process';
            instanceDetails.add(new Map<String,Object>{ 'Status' => status,
                                                        'Detail' => detail,
                                                        'ChainId' => chain.Id,
                                                        'ChainName' => chain.Name,
                                                        'ChainSteps' => chain.ChainSteps__r });                          
        }          
        
        if (resolvedProcess) {
            for (Map<String,Object> instanceDetail : instanceDetails) {
                List<ChainStep__c> chainSteps = (List<ChainStep__c>) instanceDetail.get('ChainSteps');
                Integer subscribeOccurs = 0;
                Integer step = 1;
                Boolean subscribeFirst = false;
                Id chainStepId = null;
                Id subscribeConfigurationId = null;
                for (ChainStep__c chainStep : chainSteps) {
                    if (chainStep.Process__c == SubscribeProcess.Id) {
                        subscribeOccurs++;
                        if (step == 1) {
                            subscribeFirst = true;
                            chainStepId = chainStep.Id;
                            subscribeConfigurationId = (Id) chainStep.Configuration__c; // cast from string to Id
                        }
                    }
                    step++;
                }
                 
                Boolean hasSubscribe = (subscribeOccurs > 0);
   
                if (hasSubscribe)  {
                    Boolean isError = false;
                    String detail;  
                    if (! subscribeFirst) {
                        isError = true;
                        detail = 'Subscribe process not  at front of chain';
                    }
                    if (subscribeOccurs > 1) {
                        isError = true;
                        detail = 'Subscribe appears more than once in chain ['+subscribeOccurs+']';
                    }
                    
                    if (isError) {
                        instanceDetail.put('Status', 'Error');
                        instanceDetail.put('Detail', detail);
                    } 


                    SubscribeConfiguration__c subscribeConfiguration;
                    Id eventId;
                    if ( !isError ) {
                        subscribeConfiguration = subscribeConfigurationIdToSubscribeConfiguration.get(subscribeConfigurationId);
                        if (subscribeConfiguration == null) {
                            isError = true;
                            instanceDetail.put('Status', 'Error');
                            instanceDetail.put('Detail', 'Cannot resolve subscribe configuration');
                        }
                    }
                    if ( !isError ) {
                        eventId = subscribeConfiguration.Event__c;
                        if (eventId == null) {
                            isError = true;
                            instanceDetail.put('Status', 'Error');
                            instanceDetail.put('Detail', 'No event defined on subscribe configuration=['+subscribeConfigurationId+']');
                        }
                    }
                    if ( !isError ) {
                        Boolean publisherFound = false;
                        for (PublishConfiguration__c  publishConfiguration :  publishConfigurations) {
                            if (publishConfiguration.Event__c == eventId) {
                                publisherFound = true;
                            }
                        }
                        if (!publisherFound) {
                            Event__c event = eventIdToEvent.get(eventId);
                            String eventName  = (event == null) ? '' : event.Name;
                            instanceDetail.put('Status', 'Warning');
                            instanceDetail.put('Detail', 'No publisher is configured to publish event=['+eventName+']');
                        }
                    }
                }
            }
        }

        system.debug(json.serializePretty(instanceDetails));
        List<HealthController.Health> healths = new List<HealthController.Health>();
        for (Map<String,Object> instanceDetail : instanceDetails) {
            HealthController.Health health = new HealthController.Health();
            health.ChainId = (Id) instanceDetail.get('ChainId');
            health.ChainName = (String) instanceDetail.get('ChainName');
            health.Detail = (String) instanceDetail.get('Detail');
            health.Status = (String) instanceDetail.get('Status');
            healths.add(health);
        } 
          
        return healths;
    }
}