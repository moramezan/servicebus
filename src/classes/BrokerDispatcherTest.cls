@IsTest class BrokerDispatcherTest {
    
    @TestSetup static void testSetup() {
        OAuthSetting__c setting = OAuthSetting__c.getOrgDefaults();
        setting.RunningUserId__c = UserInfo.getUserId();
        upsert setting;
    }
    
    static testmethod void coverStart() {
        //arrange
        BrokerDispatcher dispatcher = new BrokerDispatcher();
        
        //act
        Object iterator = dispatcher.start(null);
        
        //assert
        System.assert(iterator instanceof Iterable<SObject>);
    }
    
    static testmethod void coverExecute() {
        //arrange
        List<SObject> scopes = new List<SObject>();
        BrokerDispatcher dispatcher = new BrokerDispatcher();
        
        //act
        dispatcher.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), scopes);
        
        //assert
        System.assert(scopes.isEmpty());
    }
    
    static testmethod void coverFinish() {
        //arrange
        BrokerDispatcher dispatcher = new BrokerDispatcher();
        
        //act
        dispatcher.finish(null);
        
        //assert
        Integer expectedCount = 0;
        Integer actualcount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount);
    }
}