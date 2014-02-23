global class LogInitializer implements Process.Plugin {
    
    public class LogInitializerException extends Exception {}
    
    public class Eda {
        public SObject configurable = LogConfiguration__c.SObjectType.newSobject();
        public String icon = 'pencil';
    }
    
    public Process.PluginDescribeResult describe () {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'LogInitializer';
        plugin.Description = 'Creates a grouping identifier which all subsequent LogWriter processes log against.';
        plugin.Tag = 'Event Driven Architecture';
        
        plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter(
                'eda__logGroupIds',
                'An identifier that associates instances of steps.',
                Process.PluginDescribeResult.ParameterType.String
            )
        };

        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> parameters = pluginRequest.inputParameters;
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        
        
         //derive the SequenceName and Position
         List<Step__c> steps = [
             SELECT Id, Position__c, Sequence__r.Name
             FROM Step__c
             WHERE Sequence__r.Name = :(String)parameters.get('eda__sequenceName')
             AND Position__c = :(Decimal) parameters.get('eda__position')
         ];
         if (steps.size() == 0) {
            throw new LogInitializerException('Unable to access the Step Position and Sequence Name');
         }
         Step__c  step = steps[0];
 
         //get group identifier instruction from configuration
         List<LogConfiguration__c> configurations = [
             SELECT Id, GroupIdentifier__c , GroupInstruction__c
             FROM LogConfiguration__c
             WHERE Id = :(Id)parameters.get('eda__configuration')
         ];
         if (configurations.size() == 0) {
            throw new LogInitializerException('Unable to access Log Configuration');
         }
         LogConfiguration__c configuration = configurations[0];
        
         // insert composite key values into log group :
         // the composite key comprises
         // 1.  the date-time stamp
         // 2.  a (fairly unique ) business group value
         Id dataId =  (Id)parameters.get('Id');
         String groupIdentifier = getBusinesGroupIdentifier(configuration, step, dataId) ;
         LogGroup__c logGroup = new LogGroup__c( LogConfiguration__c = configuration.Id,  GroupIdentifier__c = groupIdentifier, Stamp__c = System.Now());
         insert logGroup;

         // update outbound message
         List<Object> logGroupIds = (List<Object>)parameters.get('eda__logGroupIds');
         if (logGroupIds == null) {
             logGroupIds = new List<Object>();
         }
         logGroupIds.add(logGroup.Id);
         parameters.put('eda__logGroupIds', logGroupIds);

         
         return Utility.convert(new List<Map<String,Object>>{parameters});
    }

 
    
    @TestVisible
    private static SObject getHydrated(Id theId) {
        try {
            Schema.describesobjectresult d = theId.getSObjectType().getDescribe();
            Map<String, Schema.SObjectField> m = d.fields.getMap();
            String soql = 'SELECT ' + String.join(new List<String>(m.keySet()), ',') + ' FROM ' + d.getName() + ' WHERE id =:theId';
            return Database.query(soql);
        } catch (Exception e) {
            throw new LogInitializerException('Cannot hydate SObject with Id=[' + theId + ']' + e.getStackTraceString());
        }
    }


    @TestVisible
    private static String getIdentifer(String key, SObject so) {
        return (String) so.get(key);
    }
    
    
    @TestVisible
    private static String getBusinesGroupIdentifier(LogConfiguration__c configuration, Step__c  step,  Id dataId) {

        //  default :
        //
        //  "sequence name" and "step position"
        //  (always use this if GroupIdentifier__c from configuration equates to null)
        String defaultGroupIdentifier =  step.Sequence__r.Name + '-' + step.Position__c;
        
        
        //  preferred alternatives :
        //
        //     alternative 1  use non-null GroupIdentifier__c from configuration
        //     even better
        //     alternative 2  attempt obtain a user friendly "business id" from the
        //                    object by defining a field of that object in the
        //                    GroupInstruction__c field
        //                    if successful, any entry in GroupIdentifier__c is ignored
        
        String groupIdentifier =  configuration.GroupIdentifier__c;
        String groupInstruction =  configuration.GroupInstruction__c;
        
        String businessId;
        if ( !String.isBlank(groupInstruction) ) {
            try {
                businessId = getIdentifer(groupInstruction,   getHydrated(dataId)   );
            } catch (Exception e) {
                // swallow / non-intrusive - default acceptable
            }
        }
              
        if ( String.isBlank(groupIdentifier) ) {
            groupIdentifier = defaultGroupIdentifier;
        }
              
        if ( !String.isBlank(businessId) ) {
            groupIdentifier = businessId;
        }
       
        return groupIdentifier;
    }

}