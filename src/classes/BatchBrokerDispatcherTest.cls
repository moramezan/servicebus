@IsTest public class BatchBrokerDispatcherTest {

    static testmethod void coverStart() {
        //arrange
        BatchBrokerDispatcher dispatcher = new BatchBrokerDispatcher();
        
        //act
        Object queryLocator = dispatcher.start(null);
        
        //assert
        System.assert(queryLocator instanceof Database.QueryLocator);
    }
    
    static testmethod void coverExecute() {
        //arrange
        List<Message__c> scope = new List<Message__c>();
        BatchBrokerDispatcher dispatcher = new BatchBrokerDispatcher();
        
        //act
        dispatcher.execute(null, scope);
        
        //assert
        System.assert(scope.isEmpty());
    }
    
    static testmethod void coverFinish() {
        //arrange
        BatchBrokerDispatcher dispatcher = new BatchBrokerDispatcher();
        
        //act
        dispatcher.finish(null);
        
        //assert
        Integer expectedCount = 0;
        Integer actualcount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount);
    }
    
    
    
}