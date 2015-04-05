public with sharing class EnqueuedGate {

    public String Event;

    private class EnqueuedGateException extends Exception {}

    /**
     * @docs ProcessEnqueuedGate.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'EnqueuedGate';
        public String Description = 'Aggregates a collection of having the same Job Id.';
        public String Icon = 'arrow_join';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessEnqueuedGate').getUrl();
        public Integer Limits = 20; //leave half of 200 (Total number of SOQL queries issued)

        public Map<String,String> Inputs = new Map<String,String>{
            '__QueueableId' => 'Job Id that associates gated messages.'
        };

        public Map<String,String> Outputs = new Map<String,String>{
            'esb__GateItemsQueryString' => 'STRING of the query that locates the items that hold events correlated by Job Id.',
            'esb__GateItemsFieldName' => 'STRING of the item field name that contains the serialized event data.'
        };
    }

    @TestVisible static private Boolean DeletionEnabled = true;


    override public String toString() {
        if (!SObjectType.EnqueuedGateItem__c.Createable) throw new ApexDomain.CrudException('!SObjectType.EnqueuedGateItem__c.Createable');

        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(this.Event);


        if (!inputEvent.containsKey('__Hops'))
            throw new EnqueuedGateException('Input event missing mandatory __Hops parameter');
        if (!inputEvent.containsKey('__QueueableId'))
            throw new EnqueuedGateException('Input event missing mandatory __QueueableId parameter');

        // housekeeping / deletion strategy
        Boolean isDeletionEnabled = DeletionEnabled;
        Integer maximumDays = 30;
        Integer maximumItems = 10000;
        performDefaultDeletionStrategy(isDeletionEnabled, maximumDays, maximumItems);

        // The count of enqueued messages having a given queueable Id (Job Id)
        // defines the release trigger threshold.
        // If the count of messages having a given queueable Id buffered in the QueueableGate
        // do not equate to that threshold count, nothing is
        // released, ... 'the assumption being that more messages having that specific
        // queueable Id are still to arrive at the Gate process
        String queueableId = (String)inputEvent.get('__QueueableId');
        Integer queueableCount = 0;
        for (Message__c message : [SELECT Id, Event__c FROM Message__c WHERE QueueableId__c = :queueableId]) {
          Map<String,Object> messageEvent = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
          if ((Integer)inputEvent.get('__Hops') == 1) queueableCount++;
        }

        insert new EnqueuedGateItem__c(
            GateGroup__c = queueableId,
           // Event__c = Json.serializePretty(stripDoubleUnderScore(inputEvent))
           Event__c = Json.serializePretty(inputEvent)
        );

        List<EnqueuedGateItem__c> EnqueuedGateItems = [
            SELECT Id, Event__c
            FROM EnqueuedGateItem__c
            WHERE GateGroup__c = :queueableId
        ];


        if (queueableCount != EnqueuedGateItems.size()) {
            //this is not the last item, so let's swallow
            return Json.serialize(new List<Map<String,Object>>());
        }


        // RELEASE :

        // derive common parameters
        // this isn't strictly correct from the perspective of
        // 'common' meaning parameters at the point of insertion of the message by Job()
        // but from the perspective of 'these parameters are all the same and appear on
        // every underlying EnqueuedGate item parameters collection' .. it is correct
        Map<String,Object> commonParameters = getCommonParameters(EnqueuedGateItems);

        List<Map<String,Object>> parameteres = new List<Map<String,Object>>();
        for (EnqueuedGateItem__c EnqueuedGateItem : EnqueuedGateItems) {
            parameteres.add((Map<String,Object>)json.deserializeUntyped(EnqueuedGateItem.Event__c));
        }

        //this is the last item, let's release
        //conceptual note:
        //  this is a *new* message, not an arbitary message triggering the release
        //  that has now metamorphosised into something else.
        //  Because it is a *new* message, extra care taken to
        //  null out conceptually incorrect parameters

        //would have been nice to use a QueryLocator to give us compile-time
        //validation of the query string, but it reads out the binds as :tmpVar1
        String fieldName = SObjectType.EnqueuedGateItem__c.Fields.Event__c.Name;
        String queryString = ''
            + 'SELECT ' + fieldName + ' '
            + 'FROM EnqueuedGateItem__c '
            + 'WHERE GateGroup__c = \'' + queueableId + '\''
        ;

        inputEvent = cleanParameters(inputEvent); // start with a clean parameters collection
        inputEvent.putAll(commonParameters);   // add the common parameters ...
        inputEvent.put('esb__GateItemsQueryString', queryString);
        inputEvent.put('esb__GateItemsFieldName', fieldName);

        return Json.serialize(new List<Map<String,Object>>{inputEvent});
    }




    private static void performDefaultDeletionStrategy(Boolean isEnabled, Integer maximumDays, Integer maximumItems) {
        if (!SObjectType.EnqueuedGateItem__c.Deletable) throw new ApexDomain.CrudException('!SObjectType.EnqueuedGateItem__c.Deletable');

        DateTime now = System.now();
        IEnqueuedGateItemProvider EnqueuedGateItemProviderTime = new EnqueuedGateItemProviderTime(now, maximumDays);
        IEnqueuedGateItemProvider EnqueuedGateItemProviderCount = new EnqueuedGateItemProviderCount(maximumItems);

        EnqueuedGateDeletionProvider EnqueuedGateDeletionProvider =  new EnqueuedGateDeletionProvider(
            isEnabled, EnqueuedGateItemProviderTime, EnqueuedGateItemProviderCount
        );
        EnqueuedGateDeletionProvider.deleteEnqueuedGateGroups();
    }


    public class EnqueuedGateDeletionProvider {
        private Boolean IsEnabled;
        private IEnqueuedGateItemProvider EnqueuedGateItemProviderTime;
        private IEnqueuedGateItemProvider EnqueuedGateItemProviderCount;

        public EnqueuedGateDeletionProvider(Boolean isEnabled, IEnqueuedGateItemProvider EnqueuedGateItemProviderTime, IEnqueuedGateItemProvider EnqueuedGateItemProviderCount) {
               this.IsEnabled = isEnabled;
            this.EnqueuedGateItemProviderTime  = EnqueuedGateItemProviderTime;
            this.EnqueuedGateItemProviderCount = EnqueuedGateItemProviderCount;
        }

        public void deleteEnqueuedGateGroups() {
            if (this.IsEnabled) {
                Database.delete(getEnqueuedGateIdFromGroupIds(this.EnqueuedGateItemProviderTime.getEnqueuedGateGroupIds()));   // RULE 1
                Database.delete(getEnqueuedGateIdFromGroupIds(this.EnqueuedGateItemProviderCount.getEnqueuedGateGroupIds()));  // RULE 2
            }
        }
    }

    /*
     *  Helper - the GateGroup for the *original* Gate was an Id
     *           the GateGroup for this Gate implementation is a String
     *
     *           Deletion based on Ids at the parent (Group) level:
     *           we need this helper function to supply deletable Ids at the child level
     *           as supplying the parent group Ids for cascading parent child delete
     *           (master/detail) no longer makes sense
     */
    private static List<id> getEnqueuedGateIdFromGroupIds(Set<String> EnqueuedGateGroupIds) {
        return new List<Id>((
            new Map<Id,EnqueuedGateItem__c>([
                SELECT Id
                FROM EnqueuedGateItem__c
                WHERE  GateGroup__c IN :EnqueuedGateGroupIds
            ])
        ).keySet());
    }
    public interface IEnqueuedGateItemProvider {
        Set<String> getEnqueuedGateGroupIds();
    }


    public class MockEnqueuedGateItemProviderTime implements IEnqueuedGateItemProvider {
        private String OverThreshold;

        public MockEnqueuedGateItemProviderTime(String overThreshold) {
            this.OverThreshold = overThreshold;
        }

        public Set<String> getEnqueuedGateGroupIds() {
            List<EnqueuedGateItem__c> EnqueuedGateItemsOverDateThreshold =  EnqueuedGate.getEnqueuedGateItemsOverDateThresholdMock(this.OverThreshold);
            return EnqueuedGate.getEnqueuedGateGroupIds(EnqueuedGateItemsOverDateThreshold);
        }
    }


    // note can't really test this properly (system field createdDate)
    public class EnqueuedGateItemProviderTime implements IEnqueuedGateItemProvider {
        private DateTime Now;
        private Integer  MaximumDays;

        public EnqueuedGateItemProviderTime(DateTime now, Integer maximumDays) {
            this.Now = now;
            this.MaximumDays = maximumDays;
        }

        public Set<String> getEnqueuedGateGroupIds() {
            DateTime dateThreshold = EnqueuedGate.getDateThreshold(this.Now, this.MaximumDays);
            List<EnqueuedGateItem__c> EnqueuedGateItemsOverDateThreshold =  EnqueuedGate.getEnqueuedGateItemsOverDateThresholdImpl(DateThreshold);
            return EnqueuedGate.getEnqueuedGateGroupIds(EnqueuedGateItemsOverDateThreshold);
        }
    }


    public class EnqueuedGateItemProviderCount implements IEnqueuedGateItemProvider {
        private Integer MaximumItems;

        public EnqueuedGateItemProviderCount(Integer maximumItems) {
            this.MaximumItems = maximumItems;
        }

        public Set<String> getEnqueuedGateGroupIds() {
            Integer countThreshold = EnqueuedGate.getCountThreshold(this.MaximumItems);
            List<EnqueuedGateItem__c> EnqueuedGateItemsOverCountThreshold = EnqueuedGate.getEnqueuedGateItemsOverCountThreshold(countThreshold );
            return EnqueuedGate.getEnqueuedGateGroupIds(EnqueuedGateItemsOverCountThreshold);
        }
    }


    @testVisible
    private static DateTime getDateThreshold(DateTime now, Integer maximumDays) {
        return now.addDays(maximumDays * -1);
    }


    @testVisible
    private static Integer getCountThreshold(Integer maximumItems) {
        Integer threshold = [SELECT COUNT() FROM EnqueuedGateItem__c LIMIT 10000] - maximumItems ; //#782
        return  (threshold > 0) ? threshold : 0;
    }


    @testVisible
    private  static List<EnqueuedGateItem__c> getEnqueuedGateItemsOverCountThreshold(Integer countThreshold) {
        return [
            SELECT Id, Name, GateGroup__c, Event__c, CreatedDate
            FROM EnqueuedGateItem__c
            ORDER BY Id
            LIMIT :countThreshold
        ];
    }


    // note can't really test this properly (system field createdDate)
    @testVisible
    private static List<EnqueuedGateItem__c> getEnqueuedGateItemsOverDateThresholdImpl(DateTime DateThreshold) {
        return [
            SELECT Id, Name, GateGroup__c, CreatedDate
            FROM EnqueuedGateItem__c WHERE CreatedDate < :DateThreshold   // :DateThreshold > CreatedDate
        ];
    }


    @testVisible
    private static List<EnqueuedGateItem__c> getEnqueuedGateItemsOverDateThresholdMock(String overThreshold) {
        List<EnqueuedGateItem__c> EnqueuedGateItems = new   List<EnqueuedGateItem__c>();
        for (EnqueuedGateItem__c EnqueuedGateItem : [SELECT Id, Name, GateGroup__c, Event__c, CreatedDate FROM EnqueuedGateItem__c LIMIT 10000]) { //#782
            if (EnqueuedGateItem.Event__c == overThreshold) {
                EnqueuedGateItems.add(EnqueuedGateItem);
            }
        }

        return EnqueuedGateItems;
    }


    @testVisible
    private static Set<String> getEnqueuedGateGroupIds(List<EnqueuedGateItem__c> EnqueuedGateItems) {
        Set<String> EnqueuedGateGroupIds = new Set<String>();
        for (EnqueuedGateItem__c EnqueuedGateItem : EnqueuedGateItems) {
            EnqueuedGateGroupIds.add(EnqueuedGateItem.GateGroup__c);
        }

        return EnqueuedGateGroupIds;
    }


    @testVisible
    private static Map<String,Object> getCommonParameters(List<EnqueuedGateItem__c> EnqueuedGateItems) {
        // iteration 1
        Set<String> allKeys = new Set<String>();
        for(EnqueuedGateItem__c EnqueuedGateItem :EnqueuedGateItems) {
            Map<String,Object> EnqueuedGateItemParameters = (Map<String,Object>)json.deserializeUntyped(EnqueuedGateItem.Event__c);
            allKeys.addAll(EnqueuedGateItemParameters.keySet());
        }

        // iteration 2
        Map<String,Object> commonParameters = new Map<String,Object>();
        for (String key : allKeys) {
            Integer i = 1;
            Boolean same = true;
            Object value = null;
            for(EnqueuedGateItem__c EnqueuedGateItem :EnqueuedGateItems) {
                Map<String,Object> EnqueuedGateItemParameters = (Map<String,Object>)json.deserializeUntyped(EnqueuedGateItem.Event__c);
                Object newValue = EnqueuedGateItemParameters.get(key);
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

    /*
     * #823 stripping any and all __ parameters from Gate Items
     *  - nobody (inc bigass) can rely on those keys and values
     *  - the "rehydrated" events are much easier on the eye.
     */
    @testVisible
    private static Map<String,Object> stripDoubleUnderScore(Map<String,Object> inputEvent) {
        Map<String,Object> result = new Map<String,Object>();
        for (String key : inputEvent.keySet()) {
            Object value = (Object)inputEvent.get(key);
            if (!key.startsWith('__')) {
                result.put(key, value);
            }
        }

        return result;
    }

}