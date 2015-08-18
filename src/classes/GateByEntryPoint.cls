public class GateByEntryPoint extends ApexClassModel.BaseProcess {

    private class GateByEntryPointException extends Exception {}

    /**
     * @docs ProcessGateByEntryPoint.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        String Tag = 'Enterprise Service Bus';
        String Name = 'Gate By Entry Point';
        String Description = 'Aggregates a collection of messages having the same Entry Point Id.';
        String Icon = 'arrow_join';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessGateByEntryPoint').getUrl();
        Integer Limits = 50; //max sync limit
        String Cardinality = 'Fewer';

        Map<String,String> Inputs = new Map<String,String>{
            'EntryPointUuid' => 'Entry Point Id that associates gated messages.'
        };

        Map<String,String> Outputs = new Map<String,String>{
            'GateItemsQueryString' => 'STRING of the query that locates the items that hold events correlated by Job Id.',
            'GateItemsFieldName' => 'STRING of the item field name that contains the serialized event data.'
        };
    }

    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {

        if (!inputEvent.containsKey('EntryPointUuid'))
            throw new GateByEntryPointException('Input event missing mandatory EntryPointUuid parameter');
        if (!inputEvent.containsKey('Range'))
            throw new GateByEntryPointException('Input event missing mandatory Range parameter');
        if (!inputEvent.containsKey('Chunk'))
            throw new GateByEntryPointException('Input event missing mandatory Chunk parameter');
        if (!inputEvent.containsKey('Route'))
            throw new GateByEntryPointException('Input event missing mandatory Route parameter');

        String entryPointUuid = (String)inputEvent.get('EntryPointUuid');
        Integer chunkTotal = (Integer)inputEvent.get('Range');
        Integer chunk = (Integer)inputEvent.get('Chunk');
        String route = (String)inputEvent.get('Route');

        Boolean release = isRelease(entryPointUuid, chunkTotal, chunk);

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
                + 'WHERE EntryPointUuid__c = \'' + entryPointUuid + '\'  AND Route__c  = \'' + route + '\''
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
        inputEvent.put('GateItemsQueryString', queryString);
        inputEvent.put('GateItemsFieldName', fieldName);

        return new List<Map<String,Object>>{inputEvent};
    }



    @testVisible
    private static Map<String,Object> getCommonParameters(List<Message__c> messages) {
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



    @testVisible
    private static Map<String,Object> cleanParameters(Map<String,Object> inputEvent) {
        for (String input : inputEvent.keySet()) {
            Object value = (Object)inputEvent.get(input);
            value =  (input.startsWith('__') || input.startsWith('esb__'))  ? value : null;
            inputEvent.put(input, value);
        }

        return inputEvent;
    }
    
    @testVisible
    private static Boolean isRelease(String entryPointUuid, Integer chunkTotal, Integer chunk) {
        // Release trigger:
        // given :
        //   A = [Non-Completed status messages having a given entryPointUuid]
        //   Z = [Started status messages having a given entryPointUuid and having null Exception]
        //   T = ChunkTotal
        //   C  = Chunk
        //
        //  Rule 1: For-Each[A] we expect a status of Started
        //            Only Started messages on database
        //  Rule 2: Size(Z) == T
        //            Count of "Non-Exception Started status messages" should equate to ChunkTotal
        //            implying "no more to execucute after this"
        //  Rule 3: T == C
        //            Only one release for the given entryPointUuid at the "end"
        //            where "end"
        //            defined as "chunk offset matches chunk total" (eg 10th chunk out of 10 chunks)

        List<Message__c> messages = [
            SELECT Id, Status__c, Exception__c
            FROM Message__c
            WHERE (Status__c = 'Buffered' OR Status__c = 'Paused' OR  Status__c = 'Started')
            AND
            EntryPointUuid__c = :entryPointUuid
        ];

        Integer nonExceptionStartedCount  = 0;
        Boolean onlyStartedStatus = true;
        for (Message__c message : messages) {
            if (message.Status__c != 'Started') onlyStartedStatus = false;
            if ((message.Status__c == 'Started')  && (message.Exception__c == null)) nonExceptionStartedCount++;
        }
        Boolean correctChunks = (chunkTotal == nonExceptionStartedCount);
        Boolean lastChunk = (chunkTotal == chunk);


        return  (onlyStartedStatus && correctChunks && lastChunk);
    }
    
}