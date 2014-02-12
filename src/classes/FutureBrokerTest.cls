@isTest
private class FutureBrokerTest {

    static testMethod void callingEnqueueSuccessfullyCallEnqueueImp() {
        //arrange 
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = markProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = terminateProcess.Id);
        insert stepA1;
        insert stepA2;
        
        
        insert new BrokerSettings__c(BrokerClassName__c = FutureBroker.class.getName() );
        
        //act 
        Test.startTest();
        Broker.enqueue(chainNameA, '000000000000000AAA'); 
        Test.stopTest();
        
        // assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, isDeleted 
            FROM PersistentData__c 
            WHERE isDeleted = false
            ALL ROWS
        ];
        
        Integer actualCount = persistentDatas.size();
        
        
        // assert
        // Note : Under FutureBroker we are not limited to one Broker execute
        // but all broker executes take place under one execution context under test mode
        Integer expectedCount = 0; 
        System.assertEquals(expectedCount , actualCount); 
    } 
    
    
    static testMethod void callingBrokerStartSuccessfullyCallsStartImp() {
        //arrange 
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = markProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = terminateProcess.Id);
        insert stepA1;
        insert stepA2;

        insert new BrokerSettings__c(BrokerClassName__c = FutureBroker.class.getName() );
        
        // scenario:
        // resolved state , assume manual intervention to set status to 'Reprocess'
        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainNameA,
            'eda__sequence' => 1, // not zero !!!
            'id' => '000000000000000AAA'
        };
        PersistentData__c persistentData = new PersistentData__c(
            ChainStep__c = stepA1.Id,
            Status__c = 'Reprocess',
            Notification__c = Json.serializePretty(notification)
        );
        insert persistentData;
        
        
        //act 
        Broker.start(); 
        
        // assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, isDeleted 
            FROM PersistentData__c 
            WHERE isDeleted = false
            ALL ROWS
        ];
        
        Integer actualCount = persistentDatas.size();
        
        // assert
        Integer expectedCount = 0; 
        System.assertEquals(expectedCount , actualCount); 
    } 


    static testMethod void callingEnqueueWithInternallyFailingPluginSuccessfullyWritesErrorMessageToPersistentData() {
        //arrange 
        Process__c failureProcess = Processes.generateOne(FailurePlugin.class);
        
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        Integer sequenceA1 = 1;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = failureProcess.Id);
        insert stepA1;
        
        insert new BrokerSettings__c(BrokerClassName__c = FutureBroker.class.getName() );
        
        //act 
        Broker.enqueue(chainNameA, '000000000000000AAA'); 
        
        
        // assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, Message__c, isDeleted 
            FROM PersistentData__c 
            WHERE isDeleted = false
            ALL ROWS
        ];
        Integer actualCount = persistentDatas.size();
        
        // assert
        Integer expectedCount = 1; 
        System.assertEquals(expectedCount , actualCount); 
        
        String expectedProcessName = FailurePlugin.class.getName();
        System.assertEquals(expectedProcessName, persistentDatas[0].Process__r.Name);
        
        String expectedMessage = FailurePlugin.FailureMessage;
        System.assertEquals(expectedMessage, persistentDatas[0].Message__c );
    } 


    /*static testMethod void callingBuildHandlerCommandReturnsExpectedCommand() {
        //arrange 
        PersistentData__c persistentData = new PersistentData__c( );
        insert persistentData;
        Id persistentDataId = persistentData.Id;
        
        //act 
        String actualCommand = FutureBroker.buildHandlerCommand(persistentDataId);
        
        // assemble
        String expectedCommand = persistentDataId;
        
        // assert
        System.assert(actualCommand.contains(expectedCommand)); 
    }*/
}