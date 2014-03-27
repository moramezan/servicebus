@isTest public class BatchBrokerDispatcherTest {

    static testMethod void coverStart() {
        //arrange
        BatchBrokerDispatcher dispatcher = new BatchBrokerDispatcher();
        
        //act
        Object queryLocator = dispatcher.start(null);
        
        //assert
        System.assert(queryLocator instanceof Database.QueryLocator);
    }
    
    static testMethod void coverExecute() {
        //arrange
        List<Message__c> scope = new List<Message__c>();
        BatchBrokerDispatcher dispatcher = new BatchBrokerDispatcher();
        
        //act
        dispatcher.execute(null, scope);
        
        //assert
        System.assert(scope.isEmpty());
    }
    
    static testMethod void coverFinish() {
        //arrange
        BatchBrokerDispatcher dispatcher = new BatchBrokerDispatcher();
        
        //act
        dispatcher.finish(null);
        List<Message__c> messages = [SELECT Id FROM Message__c];
        
        //assert
        System.assert(messages.isEmpty());
    }
    
    
    
}