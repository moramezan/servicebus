global with sharing class GateByJob extends ApexClassModel.BaseProcess {

    private class GateByJobException extends Exception {}

    /**
     * @docs ProcessGateByJob.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Gate By Job';
        public String Description = 'Aggregates a collection of messages having the same Job Id.';
        public String Icon = 'arrow_join';
        public String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessGateByJob').getUrl();
        public Integer Limits = 50; //max sync limit
        public String Cardinality = 'Fewer';
        
        public Map<String,String> Inputs = new Map<String,String>{
            '__QueueableId' => 'Job Id that associates gated messages.'
        };

        public Map<String,String> Outputs = new Map<String,String>{
            'esb__GateItemsQueryString' => 'STRING of the query that locates the items that hold events correlated by Job Id.',
            'esb__GateItemsFieldName' => 'STRING of the item field name that contains the serialized event data.'
        };
    }



    override protected List<Map<String,Object>> execute(Map<String,Object> inputEvent) {

        if (!inputEvent.containsKey('__QueueableId'))
            throw new GateByJobException('Input event missing mandatory __QueueableId parameter');
        if (!inputEvent.containsKey('__ChunkTotal'))
            throw new GateByJobException('Input event missing mandatory  __ChunkTotal parameter');
        if (!inputEvent.containsKey('__Chunk'))
            throw new GateByJobException('Input event missing mandatory __Chunk parameter');
        if (!inputEvent.containsKey('__Position'))
            throw new GateByJobException('Input event missing mandatory __Position parameter');
        if (!inputEvent.containsKey('__SequenceName'))
            throw new GateByJobException('Input event missing mandatory __SequenceName parameter');


        String queueableId = (String)inputEvent.get('__QueueableId');
        Integer chunkTotal = (Integer)inputEvent.get('__ChunkTotal');
        Integer chunk = (Integer)inputEvent.get('__Chunk');
        Integer position = (Integer)inputEvent.get('__Position');
        String sequenceName = (String)inputEvent.get('__SequenceName');
        String route = sequenceName + '#' +  position;

        Boolean release = isRelease(queueableId, chunkTotal, chunk);

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
                + 'WHERE QueueableId__c = \'' + queueableId + '\'  AND Step__c  = \'' + route + '\''
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
        inputEvent.put('esb__GateItemsQueryString', queryString);
        inputEvent.put('esb__GateItemsFieldName', fieldName);

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
    global static Boolean isRelease(String queueableId, Integer chunkTotal, Integer chunk) {
        // Release trigger:
        // given :
        //   A = [Non-Completed status messages having a given QueueableId]
        //   Z = [Started status messages having a given QueueableId and having null Exception]
        //   T = ChunkTotal
        //   C  = Chunk
        //
        //  Rule 1: For-Each[A] we expect a status of Started
        //            Only Started messages on database
        //  Rule 2: Size(Z) == T
        //            Count of "Non-Exception Started status messages" should equate to ChunkTotal
        //            implying "no more to execucute after this"
        //  Rule 3: T == C
        //            Only one release for the given QueueableId at the "end"
        //            where "end"
        //            defined as "chunk offset matches chunk total" (eg 10th chunk out of 10 chunks)

        List<Message__c> messages = [
            SELECT Id, Status__c, Exception__c
            FROM Message__c
            WHERE (Status__c = 'Buffered' OR Status__c = 'Paused' OR  Status__c = 'Started')
            AND
            QueueableId__c = :queueableId
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