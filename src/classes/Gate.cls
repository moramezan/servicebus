public with sharing class Gate {
    
    public String Parameters;
    
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Gate';
        public String Description = 'Aggregates a collection of messages previously marked with a correlation key.';
        public String Icon = 'arrow_join';
        public String HelpUrl = Page.GateGroupCsh.getUrl();
        public Integer Limits = 1;

        public Map<String,String> Inputs = new Map<String,String>{
            'esb__GateGroupId' => 'ID of the GateGroup the marked messages should belong to.'
        };

        public Map<String,String> Outputs = new Map<String,String>{
            'esb__Id' => 'ID of the GateGroup whose members are now all present.'
        };
    }

    @TestVisible static private Boolean DeletionEnabled = true;
    
    override public String toString() {
        if (!SObjectType.GateItem__c.Createable) throw new Broker.CrudException('!SObjectType.GateItem__c.Createable');

        // housekeeping / deletion strategy
        Boolean isDeletionEnabled = DeletionEnabled;
        Integer maximumDays = 30;
        Integer maximumItems = 10000;
        performDefaultDeletionStrategy(isDeletionEnabled, maximumDays, maximumItems);

        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        Id gateGroupId = (Id)parameters.get('esb__GateGroupId');
        Decimal count = (Decimal)parameters.get('__Count');
        
        insert new GateItem__c(
            GateGroup__c = gateGroupId,
            Parameters__c = Json.serializePretty(parameters)
        );
        
        List<GateItem__c> gateItems = [
            SELECT Id
            FROM GateItem__c
            WHERE GateGroup__c = :gateGroupId
        ];
        
        if (count != gateItems.size()) {
            //this is not the last item, so let's swallow
            return Json.serialize(new List<Map<String,Object>>());
        }
        
        //this is the last item, let's release
        parameters.put('esb__Id', gateGroupId);
        parameters.remove('__Count');
        parameters.remove('__MarkCount');
        parameters.remove('esb__GateGroupId');
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
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
        if (!SObjectType.GateItem__c.Deletable) throw new Broker.CrudException('!SObjectType.GateItem__c.Deletable');
        if (!SObjectType.GateGroup__c.Deletable) throw new Broker.CrudException('!SObjectType.GateItem__c.Deletable');  
 
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
            SELECT Id, Name, GateGroup__c, Parameters__c, CreatedDate
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
        for (GateItem__c gateItem : [SELECT Id, Name, GateGroup__c, Parameters__c, CreatedDate FROM GateItem__c]) {
            if (gateItem.Parameters__c == overThreshold) {
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
}