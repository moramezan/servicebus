@IsTest public class VerticalBrokerDispatcherTest {
    
    @TestSetup static void testSetup() {
        OAuthSetting__c setting = OAuthSetting__c.getOrgDefaults();
        setting.RunningUserId__c = UserInfo.getUserId();
        upsert setting;
    }
    
    static testmethod void coverStart() {
        //arrange
        VerticalBrokerDispatcher dispatcher = new VerticalBrokerDispatcher();
        
        //act
        Object iterator = dispatcher.start(null);
        
        //assert
        System.assert(iterator instanceof Iterable<SObject>);
    }
    
    static testmethod void coverExecute() {
        //arrange
        List<SObject> scopes = new List<SObject>();
        VerticalBrokerDispatcher dispatcher = new VerticalBrokerDispatcher();
        
        //act
        dispatcher.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), scopes);
        
        //assert
        System.assert(scopes.isEmpty());
    }
    
    static testmethod void coverFinish() {
        //arrange
        VerticalBrokerDispatcher dispatcher = new VerticalBrokerDispatcher();
        
        //act
        dispatcher.finish(null);
        
        //assert
        Integer expectedCount = 0;
        Integer actualcount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount);
    }
}