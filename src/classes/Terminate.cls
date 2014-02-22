public with sharing class Terminate implements Process.Plugin {
    
    public class Eda {
        public String icon = 'stop';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Mandatory process that terminates each chain.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Terminate';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //if we got here from a boomerang, back to where you came from!
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        Object data = parameters.get('eda__boomerangChainStepIds');
        
        if (data == null) {
            //no boomerangs
            return Utility.convert(parametersList);
        }

        List<Id> chainStepIds = (List<Id>)System.Json.deserialize(System.Json.serialize(data), List<Id>.class);
        if (chainStepIds.isEmpty()) {
            //boomerangs finished
            return Utility.convert(parametersList);
        }
        
        //pop one boomerang off stack
        Id lastId = chainStepIds.remove(chainStepIds.size() - 1);
        ChainStep__c chainStep = [
            SELECT Id, Chain__r.Name, Sequence__c
            FROM ChainStep__c
            WHERE Id = :lastId
        ];
        
        parameters.put('eda__boomerangChainStepIds', chainStepIds);
        parameters.put('eda__chainName', chainStep.Chain__r.Name );
        parameters.put('eda__sequence', chainStep.Sequence__c );
        parametersList.add(parameters);

        return Utility.convert(parametersList);
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
        
        List<Process__c> terminateProcesses  = [SELECT id, Name
                                           FROM Process__c
                                           WHERE Name = 'Terminate'
                                          ];
        Process__c  terminateProcess = (terminateProcesses.size() > 0) ? terminateProcesses[0] : null;
        Boolean resolvedProcess = (terminateProcess != null);
        
        // Error conditions:
        // * Chain with no Terminate (error)
        // * Chain with more than one Terminate (error)
        // * Terminate that's not at the end (error)
        for (Chain__c  chain : chains)
        {
            Integer terminateCount = 0;
            for (ChainStep__c chainStep : chain.ChainSteps__r) {
                if (resolvedProcess) {
                    if (chainStep.Process__c == terminateProcess.Id) {
                        terminateCount++;
                    }
                }
            }

            HealthController.Health health = new HealthController.Health();
            health.ChainId = chain.Id;
            health.ChainName = chain.Name;
            health.Detail = 'Cannot resolve Id of Terminate process';
            health.Status = 'Unknown';
            if (resolvedProcess)
            {
                health.Detail = 'Terminate Check(s)';
                health.Status = 'Ok';
                
                Boolean noTerminateError = (terminateCount == 0);
                Boolean gtOneTerminateError = (terminateCount > 1);
                Boolean terminateNotAtEndError = (chain.ChainSteps__r.size() > 0) ?
                                            (chain.ChainSteps__r[chain.ChainSteps__r.size()-1].Process__c != terminateProcess.Id) :
                                            false;
                
               if (terminateNotAtEndError) {
                    health.Detail = 'Terminate process not present at end of chain';
                    health.Status = 'Error';
                }
                if (noTerminateError) {
                    health.Detail = 'No Terminate found in chain';
                    health.Status = 'Error';
                }
                if (gtOneTerminateError) {
                    health.Detail = 'More than one Terminate found in chain';
                    health.Status = 'Error';
                }
            }

            healths.add(health);
        }
            
        System.debug(json.serializePretty(healths));
        return healths;
    }
}