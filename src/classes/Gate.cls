public with sharing class Gate {
    
    public String Event;
    
    /**
     * @docs ProcessMarkGate.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Gate';
        public String Description = 'Aggregates a collection of messages previously marked with a correlation key.';
        public String Icon = 'arrow_join';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessMarkGate').getUrl();
        public Integer Limits = 20; //leave half of 200 (Total number of SOQL queries issued)

        public Map<String,String> Inputs = new Map<String,String>{
            'esb__GateGroupId' => 'ID of the GateGroup the marked messages should belong to.'
        };
        
        public Map<String,String> Outputs = new Map<String,String>{
            'esb__GateItemsQueryString' => 'STRING of the query that locates the items that hold events correlated by Mark and Gate.',
            'esb__GateItemsFieldName' => 'STRING of the item field name that contains the serialized event data.'
        };
    }

    @TestVisible static private Boolean DeletionEnabled = true;
    
    override public String toString() {
        if (!SObjectType.GateItem__c.Createable) throw new ApexDomain.CrudException('!SObjectType.GateItem__c.Createable');

        // housekeeping / deletion strategy
        Boolean isDeletionEnabled = DeletionEnabled;
        Integer maximumDays = 30;
        Integer maximumItems = 10000;
        performDefaultDeletionStrategy(isDeletionEnabled, maximumDays, maximumItems);

        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(this.Event);
        
        Id gateGroupId = (Id)inputEvent.get('esb__GateGroupId');
        Decimal count = (Decimal)inputEvent.get('__Count');
        
        insert new GateItem__c(
            GateGroup__c = gateGroupId,
            Event__c = Json.serializePretty(inputEvent)
        );
        
        List<GateItem__c> gateItems = [
            SELECT Id, Event__c
            FROM GateItem__c
            WHERE GateGroup__c = :gateGroupId
        ];
        
        if (count != gateItems.size()) {
            //this is not the last item, so let's swallow
            return Json.serialize(new List<Map<String,Object>>());
        }
        
        // derive common parameters
        // this isn't strictly correct from the perspective of 
        // 'common' meaning parameters at the point of the Mark
        // but from the perspective of 'these parameters are all the same and appear on 
        // every underlying gate item parameters collection' .. it is correct
        Map<String,Object> commonParameters = getCommonParameters(gateItems);
        
        List<Map<String,Object>> parameteres = new List<Map<String,Object>>();
        for (GateItem__c gateItem : gateItems) {
            parameteres.add((Map<String,Object>)json.deserializeUntyped(gateItem.Event__c));   
        }
        
        //this is the last item, let's release
        //conceptual note:
        //  this is a *new* message, not an arbitary message triggering the release 
        //  that has now metamorphosised into something else.
        //  Because it is a *new* message, extra care taken to
        //  null out conceptually incorrect parameters
        
        //would have been nice to use a QueryLocator to give us compile-time
        //validation of the query string, but it reads out the binds as :tmpVar1
        String fieldName = SObjectType.GateItem__c.Fields.Event__c.Name;
        String queryString = ''
            + 'SELECT ' + fieldName + ' '
            + 'FROM GateItem__c '
            + 'WHERE GateGroup__c = \'' + gateGroupId + '\''
        ;
        
        inputEvent = cleanParameters(inputEvent); // start with a clean parameters collection
        inputEvent.putAll(commonParameters);   // add the common parameters ...
        inputEvent.put('esb__GateItemsQueryString', queryString);
        inputEvent.put('esb__GateItemsFieldName', fieldName);
        inputEvent.put('__Count',null); // confuser - null out
        inputEvent.put('__MarkCount',null); // confuser - null out
        inputEvent.put('esb__GateGroupId',null); // confuser - null out        

        return Json.serialize(new List<Map<String,Object>>{inputEvent});
    }
    
 
    // Old / Max  Gate Item Deletion Rules:
    //
    // RULE 1 : for  any gateItem over date threshold ...
    //          {
    //            - add parent (gateGroup) Id to gateGroup parentSet
    //            - delete gateGroup parents where gateGroup Id in gateGroup parentSet
    //          }
    //        
    //
    // RULE 2 : order gateItems by createdDate with focus on oldest 
    //          derive excess count form oldest
    //          for oldest gateItems making up excess count ...
    //          {
    //            - add parent (gateGroup) Id to gateGroup parentSet
    //            - delete gateGroup parents where gateGroup Id in gateGroup parentSet
    //          }


    private static void performDefaultDeletionStrategy(Boolean isEnabled, Integer maximumDays, Integer maximumItems) {
        if (!SObjectType.GateItem__c.Deletable) throw new ApexDomain.CrudException('!SObjectType.GateItem__c.Deletable');
        if (!SObjectType.GateGroup__c.Deletable) throw new ApexDomain.CrudException('!SObjectType.GateItem__c.Deletable');  
 
        DateTime now = System.now();        
        IGateItemProvider gateItemProviderTime = new GateItemProviderTime(now, maximumDays);
        IGateItemProvider gateItemProviderCount = new GateItemProviderCount(maximumItems);

        GateDeletionProvider gateDeletionProvider =  new GateDeletionProvider(
            isEnabled, gateItemProviderTime, gateItemProviderCount
        );
        gateDeletionProvider.deleteGateGroups();
    }


    public class GateDeletionProvider {
        private Boolean IsEnabled;
        private IGateItemProvider GateItemProviderTime;
        private IGateItemProvider GateItemProviderCount;  

        public GateDeletionProvider(Boolean isEnabled, IGateItemProvider gateItemProviderTime, IGateItemProvider gateItemProviderCount) {
               this.IsEnabled = isEnabled;
            this.gateItemProviderTime  = gateItemProviderTime;
            this.gateItemProviderCount = gateItemProviderCount;  
        }

        public void deleteGateGroups() {
            if (this.IsEnabled) {
                Database.delete(new List<Id>(this.gateItemProviderTime.getGateGroupIds()));   // RULE 1
                Database.delete(new List<Id>(this.gateItemProviderCount.getGateGroupIds()));  // RULE 2
            }
            
            /// TODO : implement a more conservative approcach to ensure that DML limits are 
            /// never blown. Suggested implementation in commented out section below
            /// 
            /// if (this.IsEnabled) {
            ///      // RULE 1
            ///     Set<Id> getGateGroupIdsTime  =  this.gateItemProviderTime.getGateGroupIds();
            ///     List<GateItem__c> gateItemsTime = [
            ///         SELECT Id, CreatedDate, GateGroup__c 
            ///         FROM GateItem__c 
            ///         ORDER BY GateGroup__c, Id DESC
            ///         WHERE 
            ///         GateGroup__c IN :getGateGroupIdsTime
            ///         LIMIT 10000
            ///     ];
            ///     if (gateItemsTime == 10000) {
            ///         // conservative larger child delete required
            ///         // parents deleted on later gate processable invocations
            ///         Database.delete(gateItemsTime);  
            ///     } else {
            ///         // preferred, cleaner (GateGroup parents included) delete 
            ///         Database.delete(new List<Id>(getGateGroupIdsTime));  
            ///     }
            ///     
            ///     // RULE 2
            ///     Set<Id> getGateGroupIdsCount =  this.gateItemProviderCount.getGateGroupIds();
            ///     List<GateItem__c> gateItemsCount = [
            ///         SELECT Id, CreatedDate, GateGroup__c 
            ///         FROM GateItem__c 
            ///         ORDER BY GateGroup__c, Id DESC
            ///         WHERE 
            ///         GateGroup__c IN :getGateGroupIdsCount
            ///         LIMIT 10000
            ///     ];
            ///     if (gateItemsCount == 10000) {
            ///         // conservative larger child delete required
            ///         // parents deleted on later gate processable invocations
            ///         Database.delete(gateItemsCount);
            ///     } else {
            ///         // preferred, cleaner (GateGroup parents included) delete 
            ///         Database.delete(new List<Id>(getGateGroupIdsCount));  
            ///     }
            /// }    
        }
    } 
 
    
    public interface IGateItemProvider {
        Set<Id> getGateGroupIds();
    }

 
    public class MockGateItemProviderTime implements IGateItemProvider {
        private String OverThreshold;

        public MockGateItemProviderTime(String overThreshold) {
            this.OverThreshold = overThreshold;
        }

        public Set<Id> getGateGroupIds() {
            List<GateItem__c> gateItemsOverDateThreshold =  Gate.getGateItemsOverDateThresholdMock(this.OverThreshold);
            return Gate.getGateGroupIds(gateItemsOverDateThreshold);
        }
    } 


    // note can't really test this properly (system field createdDate)
    public class GateItemProviderTime implements IGateItemProvider {
        private DateTime Now; 
        private Integer  MaximumDays;
        
        public GateItemProviderTime(DateTime now, Integer maximumDays) {
            this.Now = now;
            this.MaximumDays = maximumDays;
        }

        public Set<Id> getGateGroupIds() {
            DateTime dateThreshold = Gate.getDateThreshold(this.Now, this.MaximumDays);
            List<GateItem__c> gateItemsOverDateThreshold =  Gate.getGateItemsOverDateThresholdImpl(DateThreshold);
            return Gate.getGateGroupIds(gateItemsOverDateThreshold);
        }
    } 

 
    public class GateItemProviderCount implements IGateItemProvider {
        private Integer MaximumItems;

        public GateItemProviderCount(Integer maximumItems) {
            this.MaximumItems = maximumItems;
        }

        public Set<Id> getGateGroupIds() {
            Integer countThreshold = Gate.getCountThreshold(this.MaximumItems);
            List<GateItem__c> gateItemsOverCountThreshold = Gate.getGateItemsOverCountThreshold(countThreshold );
            return Gate.getGateGroupIds(gateItemsOverCountThreshold);
        }
    } 


    @testVisible   
    private static DateTime getDateThreshold(DateTime now, Integer maximumDays) {
        return now.addDays(maximumDays * -1);
    }


    @testVisible
    private static Integer getCountThreshold(Integer maximumItems) {
        Integer threshold = [SELECT COUNT() FROM GateItem__c] - maximumItems ;
        return  (threshold > 0) ? threshold : 0;
    }


    @testVisible
    private  static List<GateItem__c> getGateItemsOverCountThreshold(Integer countThreshold) {
        return [
            SELECT Id, Name, GateGroup__c, Event__c, CreatedDate
            FROM GateItem__c 
            ORDER BY Id 
            LIMIT :countThreshold
        ];
    }


    // note can't really test this properly (system field createdDate)
    @testVisible
    private static List<GateItem__c> getGateItemsOverDateThresholdImpl(DateTime DateThreshold) {
        return [
            SELECT Id, Name, GateGroup__c, CreatedDate 
            FROM GateItem__c WHERE CreatedDate < :DateThreshold   // :DateThreshold > CreatedDate   
        ];
    }


    @testVisible
    private static List<GateItem__c> getGateItemsOverDateThresholdMock(String overThreshold) {
        List<GateItem__c> gateItems = new   List<GateItem__c>();
        for (GateItem__c gateItem : [SELECT Id, Name, GateGroup__c, Event__c, CreatedDate FROM GateItem__c]) {
            if (gateItem.Event__c == overThreshold) {
                gateItems.add(gateItem);
            }
        }

        return gateItems;
    }


    @testVisible
    private static Set<Id> getGateGroupIds(List<GateItem__c> gateItems) {
        Set<Id> gateGroupIds = new Set<Id>();
        for (GateItem__c gateItem : gateItems) {
            gateGroupIds.add(gateItem.GateGroup__c);
        }

        return gateGroupIds;
    } 

       
    @testVisible
    private static Map<String,Object> getCommonParameters(List<GateItem__c> gateItems) {
        // iteration 1
        Set<String> allKeys = new Set<String>(); 
        for(GateItem__c gateItem :gateItems) {
            Map<String,Object> gateItemParameters = (Map<String,Object>)json.deserializeUntyped(gateItem.Event__c);
            allKeys.addAll(gateItemParameters.keySet());
        }
        
        // iteration 2
        Map<String,Object> commonParameters = new Map<String,Object>();
        for (String key : allKeys) {
            Integer i = 1; 
            Boolean same = true;
            Object value = null;
            for(GateItem__c gateItem :gateItems) {
                Map<String,Object> gateItemParameters = (Map<String,Object>)json.deserializeUntyped(gateItem.Event__c);
                Object newValue = gateItemParameters.get(key);
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