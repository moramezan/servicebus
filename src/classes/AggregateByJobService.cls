public class AggregateByJobService extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}

    public class ServiceException extends Exception {}

    public class Summary extends ApexClassModel.Summary {
        String Tag = 'Service Bus';
        String Label = 'Aggregate By Job';
        String Description = 'Aggregates a collection of messages having the same Job Id.';
        String Icon = 'arrow_join';
        Integer Chunks =  200; //max sync limit
        String Cardinality = 'Fewer';
        
        Map<String,String> Inputs = new Map<String,String>{
            'JobId' => 'Job Id that associates gated messages.'
        };

        Map<String,String> Outputs = new Map<String,String>{
            'GateItemQuery' => 'STRING of the query that locates the items that hold events correlated by Job Id.',
            'GateItemField' => 'STRING of the item field name that contains the serialized event data.'
        };
    }



    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {

        if (!inputEvent.containsKey('JobId'))
            throw new ServiceException('Input event missing mandatory JobId parameter');
        if (!inputEvent.containsKey('Range'))
            throw new ServiceException('Input event missing mandatory Range parameter');
        if (!inputEvent.containsKey('Chunk'))
            throw new ServiceException('Input event missing mandatory Chunk parameter');
        if (!inputEvent.containsKey('Route'))
            throw new ServiceException('Input event missing mandatory Route parameter');
        if (!inputEvent.containsKey('SiblingIds'))
            throw new ServiceException('Input event missing mandatory SiblingIds parameter');

        String jobId = (String)inputEvent.get('JobId');
        Integer chunkTotal = (Integer)inputEvent.get('Range');
        Integer chunk = (Integer)inputEvent.get('Chunk');
        String route = (String)inputEvent.get('Route');
        Set<Id>  siblingIds  = (Set<Id>)Json.deserialize(Json.serialize(inputEvent.get('SiblingIds')), Set<Id>.class);

        
        Boolean release = isRelease(siblingIds, jobId, chunkTotal, chunk);

        if ( !release) {
            //this is not the last item, so let's swallow
            return new List<Map<String,Object>>();
        }
        


        // RELEASE :

        
        //would have been nice to use a QueryLocator to give us compile-time
        //validation of the query string, but it reads out the binds as :tmpVar1
        String fieldName = SObjectType.Message__c.Fields.Event__c.Name;
        String queryString = ''
                + 'SELECT ' + fieldName + ' '
                + 'FROM Message__c '
                + 'WHERE JobId__c = \'' + jobId + '\'  AND Route__c  = \'' + route + '\'' //JobId__c field only ever used to AGGREGATE BY JOB
                ;

        //this is the last item, let's release
        //conceptual note:
        //  treat this is a *new* message, not an arbitary message
        //  triggering the release  ( that has now metamorphosised into something else.)
        //  Because it is a *new* message, extra care taken to
        //  null out conceptually incorrect parameters

        // derive common parameters
        // this isn't strictly correct from the perspective of
        // 'common' meaning parameters at the point of insertion of the message by Job()
        // but from the perspective of 'these parameters are all the same and appear on
        // every gated message's parameters collection' .. it is correct
        Map<String,Object> commonParameters = getCommonParameters((List<Message__c>)Database.query(queryString));

        inputEvent = cleanParameters(inputEvent); // start with a clean parameters collection
        inputEvent.putAll(commonParameters);   // add the common parameters ...
        inputEvent.put('GateItemQuery', queryString);
        inputEvent.put('GateItemField', fieldName);

        return new List<Map<String,Object>>{inputEvent};
    }



    @TestVisible static Map<String,Object> getCommonParameters(List<Message__c> messages) {
        // iteration 1
        Set<String> allKeys = new Set<String>();
        for(Message__c message :messages) {
            Map<String,Object> parameters = (Map<String,Object>)json.deserializeUntyped(message.Event__c);
            allKeys.addAll(parameters.keySet());
        }

        // iteration 2
        Map<String,Object> commonParameters = new Map<String,Object>();
        for (String key : allKeys) {
            Integer i = 1;
            Boolean same = true;
            Object value = null;
            for(Message__c message :messages) {
                Map<String,Object> parameters = (Map<String,Object>)json.deserializeUntyped(message.Event__c);
                Object newValue = parameters.get(key);
                if (i == 1)
                    value = newValue;
                if (newValue != value)
                    same = false;
                value = newValue;
                i++;
            }
            if (same && (value != null))
                commonParameters.put(key, value);
        }

        return commonParameters;
    }



    @TestVisible static Map<String,Object> cleanParameters(Map<String,Object> inputEvent) {
        for (String input : inputEvent.keySet()) {
            Object value = (Object)inputEvent.get(input);
            value =  (input.startsWith(':') || input.startsWith('servicebus:'))  ? value : null;
            inputEvent.put(input, value);
        }

        return inputEvent;
    }
    
    
    @TestVisible public static Boolean isRelease(Set<Id> siblingIds, String jobId, Integer chunkTotal, Integer chunk) {
        // Release trigger:
        //
        //    NR / MB : we assume the Gate will never fail
        //              let's revisit and implement at some point
        //


        // no release if we are not the last in the chunk
        if (chunkTotal != chunk)
            return false;

        // are there any messages on the database that are
        // not completed and not part of the current chunk range
        // for the given job id
        return  [
            SELECT Id
            FROM Message__c
            WHERE Status__c != 'Completed'
            AND JobId__c = :jobId
            AND Id NOT IN :siblingIds
            LIMIT 1
        ].isEmpty();
    }
    
}