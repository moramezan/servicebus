@isTest public class BrokerTest {

    //count batch invocations
    static Integer executions = 0;
    
    //mock process
    public class Noop implements Processable {
        public List<Map<String,Object>> execute(Map<String,Object> notification) {
            BrokerTest.executions++;
            return new List<Map<String,Object>>{notification};
        }
    }
    
    static testMethod void testNotificationProgressesThroughChain() {
        //arrange processes
        Process__c noopProcess = new Process__c(Name = 'BrokerTest.Noop', ApexClass__c = 'BrokerTest.Noop');
        Process__c sinkProcess = new Process__c(Name = 'Sink', ApexClass__c = 'Sink');
        insert noopProcess;
        insert sinkProcess;
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c step1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = noopProcess.Id);
        ChainStep__c step2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = noopProcess.Id);
        ChainStep__c step3 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = sinkProcess.Id);
        insert step1;
        insert step2;
        insert step3;
        
        //arrange notification
        Map<String,Object> notification = new Map<String,Object>{
            'chainName' => chain.Name,
            'sequence' => 0
        };
        
        //arrange persistent data
        PersistentData__c data = new PersistentData__c(
            Notification__c = Json.serialize(notification),
            RecordTypeId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId
        );
        insert data;
        
        //act
        Test.startTest();
        Broker broker = new Broker();
        Database.executeBatch(broker, 1);
        Test.stopTest();
        
        Integer expectedExecutions = 2;
        Integer actualExecutions = BrokerTest.executions;
        System.assertEquals(expectedExecutions, actualExecutions);
    }
    
    static testMethod void testEnqueueByBlob() {
        //arrange processes
        Process__c noopProcess = new Process__c(Name = 'BrokerTest.Noop', ApexClass__c = 'BrokerTest.Noop');
        Process__c sinkProcess = new Process__c(Name = 'Sink', ApexClass__c = 'Sink');
        insert noopProcess;
        insert sinkProcess;
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c step1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = noopProcess.Id);
        ChainStep__c step2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = noopProcess.Id);
        ChainStep__c step3 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = sinkProcess.Id);
        insert step1;
        insert step2;
        insert step3;
        
        //arrange arguments
        String testChain = 'testChain';
        Blob data = Blob.valueOf('herpderp');
        
        //act
        Broker.enqueue(testChain, data);
        
        //arrange
        Document document = [SELECT Id, Body FROM Document];
        
        //assert
        String expectedData = 'herpderp';
        String actualData = document.Body.toString();
        System.assertEquals(expectedData, actualData);
        
        //arrange
        PersistentData__c persistentData = [SELECT Id, Notification__c FROM PersistentData__c];
        Map<String,Object> notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c);
        
        //assert
        String expectedChainName = testChain;
        String actualChainName = (String)notification.get('chainName');
        System.assertEquals(expectedChainName, actualChainName);
        
        Decimal expectedSequence = 0;
        Decimal actualSequence = (Decimal)notification.get('sequence');
        System.assertEquals(expectedSequence, actualSequence);
    }
    
    static testmethod void testDodgyProcess() {
        //arrange process
        Process__c process = new Process__c(Name = 'BrokerTest.Dodgy', ApexClass__c = 'BrokerTest.Dodgy');
        insert process;
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange step
        ChainStep__c step = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
        insert step;
        
        //act
        Test.startTest();
        Broker.enqueue('testChain', '000000000000000AAA');
        Test.stopTest();
        
        //arrange
        PersistentData__c persistentData = [SELECT Id, Message__c FROM PersistentData__c];
        
        //asserts
        String expectedMessage = 'catchable';
        String actualMessage = persistentData.Message__c;
        System.assert(actualMessage.contains(expectedMessage));
    }
    
    //mock exception
    public class DodgyException extends Exception {}
    
    //mock process
    public class Dodgy implements Processable {
        public List<Map<String,Object>> execute(Map<String,Object> notification) {
            throw new DodgyException('catchable');
        }
    }
    
    
}