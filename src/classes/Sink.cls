public with sharing class Sink implements Process.Plugin {
    
    public class Eda {
        public String icon = 'stop';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'The Sink process terminates all chains and is mandatory.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Sink';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> notification = request.inputParameters;
        
        //if we got here from a boomerang, back to where you came from!
        List<Map<String,Object>> notifications = new List<Map<String,Object>>();
        Object data = notification.get('eda__boomerangChainStepIds');
        
        if (data == null) {
            //no boomerangs
            return Utility.convert(notifications);
        }

        List<Id> chainStepIds = (List<Id>)System.Json.deserialize(System.Json.serialize(data), List<Id>.class);
        if (chainStepIds.isEmpty()) {
            //boomerangs finished
            return Utility.convert(notifications);
        }
        
        //pop one boomerang off stack
        Id lastId = chainStepIds.remove(chainStepIds.size() - 1);
        ChainStep__c chainStep = [ 
            SELECT Id, Chain__r.Name, Sequence__c 
            FROM ChainStep__c 
            WHERE Id = :lastId
        ];
        
        notification.put('eda__boomerangChainStepIds', chainStepIds);
        notification.put('eda__chainName', chainStep.Chain__r.Name );
        notification.put('eda__sequence', chainStep.Sequence__c );
        notifications.add(notification);

        return Utility.convert(notifications);
    }

    
    public static List<HealthController.Health> getHealth() {
        List<HealthController.Health> healths = new List<HealthController.Health>();
        
        List<Chain__c> chains = [SELECT id, 
                                         Name, 
                                        (SELECT id, Name, Process__c 
                                         FROM ChainSteps__r 
                                         ORDER BY Sequence__c ASC) chainSteps  
                                 FROM Chain__c
                                ];
        
        List<Process__c> sinkProcesses  = [SELECT id, Name 
                                           FROM Process__c 
                                           WHERE Name = 'Sink'
                                          ];
        Process__c  sinkProcess = (sinkProcesses.size() > 0) ? sinkProcesses[0] : null; 
        Boolean resolvedProcess = (sinkProcess != null);
        
        // Error conditions:
        // * Chain with no sink (error)
        // * Chain with more than one Sink (error)
        // * Sink that's not at the end (error)
        for (Chain__c  chain : chains) 
        {
            Integer sinkCount = 0;
            for (ChainStep__c chainStep : chain.ChainSteps__r) {
                if (resolvedProcess) {
                    if (chainStep.Process__c == sinkProcess.Id) {
                        sinkCount++;
                    }
                }
            }

            HealthController.Health health = new HealthController.Health();
            health.ChainId = chain.Id;
            health.ChainName = chain.Name;
            health.Detail = 'Cannot resolve Id of Sink process';
            health.Status = 'Unknown';
            if (resolvedProcess) 
            {
                health.Detail = 'Sink Check(s)';
                health.Status = 'Ok'; 
                
                Boolean noSinkError = (sinkCount == 0);
                Boolean gtOneSinkError = (sinkCount > 1);
                Boolean sinkNotAtEndError = (chain.ChainSteps__r.size() > 0) ? 
                                            (chain.ChainSteps__r[chain.ChainSteps__r.size()-1].Process__c != sinkProcess.Id) :
                                            false;
                
               if (sinkNotAtEndError) {
                    health.Detail = 'Sink process not present at end of chain';
                    health.Status = 'Error';
                } 
                if (noSinkError) {
                    health.Detail = 'No Sink found in chain';
                    health.Status = 'Error';
                }
                if (gtOneSinkError) {
                    health.Detail = 'More than one sink found in chain';
                    health.Status = 'Error';
                }    
            }

            healths.add(health);
        }
            
        System.debug(json.serializePretty(healths));
        return healths;
    }
}