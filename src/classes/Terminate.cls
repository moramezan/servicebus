public with sharing class Terminate implements Process.Plugin {
    
    public class Eda {
        public String icon = 'stop';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Mandatory process that terminates each sequence.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Terminate';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //if we got here from a subsequence, back to where you came from!
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        Object data = parameters.get('eda_subsequenceStepIds');
        
        if (data == null) {
            //no subsequences
            return EdaUtility.convert(parametersList);
        }

        List<Id> stepIds = (List<Id>)System.Json.deserialize(System.Json.serialize(data), List<Id>.class);
        if (stepIds.isEmpty()) {
            //subsequences finished
            return EdaUtility.convert(parametersList);
        }
        
        //pop one subsequence off stack
        Id lastId = stepIds.remove(stepIds.size() - 1);
        Step__c step = [
            SELECT Id, Sequence__r.Name, Position__c
            FROM Step__c
            WHERE Id = :lastId
        ];
        
        parameters.put('eda_subsequenceStepIds', stepIds);
        parameters.put('eda_sequenceName', step.Sequence__r.Name );
        parameters.put('eda_position', step.Position__c );
        parametersList.add(parameters);

        return EdaUtility.convert(parametersList);
    }

    
    public static List<HealthController.Health> getHealth() {
        List<HealthController.Health> healths = new List<HealthController.Health>();
        
        List<Sequence__c> sequences = [SELECT id,
                                         Name,
                                        (SELECT id, Name, Process__c
                                         FROM Steps__r
                                         ORDER BY Position__c ASC) steps
                                 FROM Sequence__c
                                ];
        
        List<Process__c> terminateProcesses  = [SELECT id, Name
                                           FROM Process__c
                                           WHERE Name = 'Terminate'
                                          ];
        Process__c  terminateProcess = (terminateProcesses.size() > 0) ? terminateProcesses[0] : null;
        Boolean resolvedProcess = (terminateProcess != null);
        
        // Error conditions:
        // * Sequence with no Terminate (error)
        // * Sequence with more than one Terminate (error)
        // * Terminate that's not at the end (error)
        for (Sequence__c  sequence : sequences)
        {
            Integer terminateCount = 0;
            for (Step__c step : sequence.Steps__r) {
                if (resolvedProcess) {
                    if (step.Process__c == terminateProcess.Id) {
                        terminateCount++;
                    }
                }
            }

            HealthController.Health health = new HealthController.Health();
            health.SequenceId = sequence.Id;
            health.SequenceName = sequence.Name;
            health.Detail = 'Cannot resolve Id of Terminate process';
            health.Status = 'Unknown';
            if (resolvedProcess)
            {
                health.Detail = 'Terminate Check(s)';
                health.Status = 'Ok';
                
                Boolean noTerminateError = (terminateCount == 0);
                Boolean gtOneTerminateError = (terminateCount > 1);
                Boolean terminateNotAtEndError = (sequence.Steps__r.size() > 0) ?
                                            (sequence.Steps__r[sequence.Steps__r.size()-1].Process__c != terminateProcess.Id) :
                                            false;
                
               if (terminateNotAtEndError) {
                    health.Detail = 'Terminate process not present at end of sequence';
                    health.Status = 'Error';
                }
                if (noTerminateError) {
                    health.Detail = 'No Terminate found in sequence';
                    health.Status = 'Error';
                }
                if (gtOneTerminateError) {
                    health.Detail = 'More than one Terminate found in sequence';
                    health.Status = 'Error';
                }
            }

            healths.add(health);
        }
            
        System.debug(json.serializePretty(healths));
        return healths;
    }
}