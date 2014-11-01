@IsTest public class VerticalBrokerDispatcherTest {
    
    static testmethod void coverStart() {
        //arrange
        VerticalBrokerDispatcher dispatcher = new VerticalBrokerDispatcher();
        
        //act
        Object iterator = dispatcher.start(null);
        
        //assert
        System.assert(iterator instanceof Iterable<Boolean>);
    }
    
    static testmethod void coverExecute() {
        //arrange
        List<Boolean> scopes = new List<Boolean>();
        VerticalBrokerDispatcher dispatcher = new VerticalBrokerDispatcher();
        
        //act
        dispatcher.execute(null, scopes);
        
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