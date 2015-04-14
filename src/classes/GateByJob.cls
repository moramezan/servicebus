public with sharing class GateByJob {
    public String Event;

    private class GateByJobException extends Exception {}

    /**
     * @docs ProcessGateByJob.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Gate By Job';
        public String Description = 'Aggregates a collection of messages having the same Job Id.';
        public String Icon = 'arrow_join';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessGateByJob').getUrl();
        public Integer Limits = 1; // Anything greater would not enable the correct release event

        public Map<String,String> Inputs = new Map<String,String>{
            '__QueueableId' => 'Job Id that associates gated messages.'
        };

        public Map<String,String> Outputs = new Map<String,String>{
            'esb__GateItemsQueryString' => 'STRING of the query that locates the items that hold events correlated by Job Id.',
                    'esb__GateItemsFieldName' => 'STRING of the item field name that contains the serialized event data.'
        };
    }



    override public String toString() {
        //// TODO ? if (!SObjectType.MESSAGE__C.Createable) throw new ApexDomain.CrudException('!SObjectType.MESSAGE__C.Createable');

        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(this.Event);

        if (!inputEvent.containsKey('__QueueableId'))
            throw new GateByJobException('Input event missing mandatory __QueueableId parameter');

        String queueableId = (String)inputEvent.get('__QueueableId');

        // Release trigger:
        // Completed Status can be ignored, so looking for a single message in Started status
        List<Message__c> messages = [
        SELECT Id, Status__c
        FROM Message__c
        WHERE (Status__c = 'Buffered' OR Status__c = 'Queued' OR  Status__c = 'Started')
        AND
        QueueableId__c = :queueableId
        ];
        Boolean release = ((messages.size() == 1) && (messages[0].Status__c == 'Started'));

        if ( !release) {
            //this is not the last item, so let's swallow
            return Json.serialize(new List<Map<String,Object>>());
        }


        // RELEASE :

        //this is the last item, let's release
        //conceptual note:
        //  treat this is a *new* message, not an arbitary message
        //  triggering the release
        //  that has now metamorphosised into something else.
        //  Because it is a *new* message, extra care taken to
        //  null out conceptually incorrect parameters

        // derive common parameters
        // this isn't strictly correct from the perspective of
        // 'common' meaning parameters at the point of insertion of the message by Job()
        // but from the perspective of 'these parameters are all the same and appear on
        // every gated message's parameters collection' .. it is correct
        List<Message__c> releasedMessages = [
        SELECT Id, Event__c
        FROM Message__c
        WHERE QueueableId__c = :queueableId
        ];
        Map<String,Object> commonParameters = getCommonParameters(releasedMessages);

        //would have been nice to use a QueryLocator to give us compile-time
        //validation of the query string, but it reads out the binds as :tmpVar1
        String fieldName = SObjectType.Message__c.Fields.Event__c.Name;
        String queryString = ''
                + 'SELECT ' + fieldName + ' '
                + 'FROM Message__c '
                + 'WHERE QueueableId__c = \'' + queueableId + '\''
                ;

        inputEvent = cleanParameters(inputEvent); // start with a clean parameters collection
        inputEvent.putAll(commonParameters);   // add the common parameters ...
        inputEvent.put('esb__GateItemsQueryString', queryString);
        inputEvent.put('esb__GateItemsFieldName', fieldName);

        return Json.serialize(new List<Map<String,Object>>{inputEvent});
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
}