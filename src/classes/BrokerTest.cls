@isTest
public class BrokerTest{

    public static boolean flagEnqueueImpl = false;
    public static boolean flagStartImpl = false;

    public class BrokerStub extends Broker { 
        public override void enqueueImpl(String chainName, Id dataId) {
            flagEnqueueImpl = true;
        }
        public override void startImpl() {
            flagStartImpl = true;
        } 
    }

 
    static testMethod void callingSurfaceExceptionSurfacesExpectedMessageOnPersistentData() {
        // arrange
        String theMessage = 'balls';
        PersistentData__c persistentData = new PersistentData__c(Notification__c = '{"id": 1, "eda__chainName": "' + 'crow' + '", "eda__sequence": ' + '1' + '}');
        insert persistentData;
        Id persistentDataId = persistentData.Id;
        Broker.BrokerException e = new Broker.BrokerException(theMessage);
        
        // act
        Broker.surfaceException( e, persistentDataId) ;
        
        // assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Notification__c, Message__c 
            FROM PersistentData__c
        ];
        
        // assert
        Integer expectedCount = 1;
        Integer actualCount = persistentDatas.size();
        System.assertEquals(expectedCount, actualCount); 
        
        String expectedMessage = theMessage;
        String actualMessage = persistentDatas[0].Message__c; 
        System.assert(actualMessage.contains(expectedMessage));
    } 
    
    static testMethod void canCorrectlyResolvePersistentDatas() {
        // arrange
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);

        String chainNameA = 'chainA';
        String chainNameB = 'chainB';
        String chainNameC = 'chainC';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        Chain__c chainB = new Chain__c(Name = chainNameB);
        Chain__c chainC = new Chain__c(Name = chainNAmeC);
        insert chainA;
        insert chainB;
        insert chainC;

        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        Integer sequenceA3 = 3;
        Integer sequenceB1 = 1;
        Integer sequenceB2 = 2;
        Integer sequenceC1 = 1;
        Integer sequenceC2 = 2;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = subscribeProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = markProcess.Id);
        ChainStep__c stepA3 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA3,Process__c = terminateProcess.Id);
        ChainStep__c stepB1 = new ChainStep__c(Chain__c = chainB.Id ,Sequence__c = sequenceB1,Process__c = wiretapProcess.Id);
        ChainStep__c stepB2 = new ChainStep__c(Chain__c = chainB.Id ,Sequence__c = sequenceB2,Process__c = terminateProcess.Id); 
        ChainStep__c stepC1 = new ChainStep__c(Chain__c = chainC.Id ,Sequence__c = sequenceC1,Process__c = markProcess.Id);
        ChainStep__c stepC2 = new ChainStep__c(Chain__c = chainC.Id ,Sequence__c = sequenceC2,Process__c = terminateProcess.Id); 
        insert stepA1;
        insert stepA2;
        insert stepA3;
        insert stepB1;
        insert stepB2;
        insert stepC1;
        insert stepC2;
        
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>{
            new PersistentData__c(Notification__c = '{"id": 1, "eda__chainName": "' + chainA.Name + '", "eda__sequence": ' + sequenceA1 + '}'),
            new PersistentData__c(Notification__c = '{"id": 2, "eda__chainName": "' + chainA.Name + '", "eda__sequence": ' + sequenceA2 + '}'),
            new PersistentData__c(Notification__c = '{"id": 3, "eda__chainName": "' + chainB.Name + '", "eda__sequence": ' + sequenceB1 + '}'),
            new PersistentData__c(Notification__c = '{"id": 4, "eda__chainName": "' + chainC.Name + '", "eda__sequence": ' + sequenceC1 + '}')
        };
        
        // act
        Broker broker = new BrokerStub();
        broker.resolve( persistentDatas);
        
        // assemble
        String actualChainName1 = '' ;
        String actualChainName2 = '' ;
        String actualChainName3 = '' ;
        String actualChainName4 = '' ;
        Integer actualSequence1 = -1 ;
        Integer actualSequence2 = -1 ;
        Integer actualSequence3 = -1 ;
        Integer actualSequence4 = -1 ;
        for (PersistentData__c persistentData : persistentDatas) {
            Map<String,Object> notification = (Map<String,Object>)System.Json.deserializeUntyped(persistentData.Notification__c);
            Integer theId = (Integer) notification.get('id');
            String theChainName = (String) notification.get('eda__chainName');
            Integer theSequence = (Integer) notification.get('eda__sequence'); 
            if (theId == 1) {
                actualChainName1 = theChainName;
                actualSequence1 = theSequence;
            }
            if (theId == 2) {
                actualChainName2 = theChainName;
                actualSequence2 = theSequence;
            
            }
            if (theId == 3) {
                actualChainName3 = theChainName;
                actualSequence3 = theSequence;
            }
            if (theId == 4) {
                actualChainName4 = theChainName;
                actualSequence4 = theSequence;
            } 
        }
        
        // assert
        Integer expectedCount = 4;
        Integer actualCount = persistentDatas.size();
        System.assertEquals(expectedCount, actualCount);
        
        String expectedChainName1 = chainNameA;
        String expectedChainName2 = chainNameA;
        String expectedChainName3 = chainNameB;
        String expectedChainName4 = chainNameC;
        Integer expectedSequence1 = sequenceA1 + 1;
        Integer expectedSequence2 = sequenceA2 + 1;
        Integer expectedSequence3 = sequenceB1 + 1;
        Integer expectedSequence4 = sequenceC1 + 1;
        System.assertEquals(expectedSequence1, actualSequence1);
        System.assertEquals(expectedSequence2, actualSequence2);
        System.assertEquals(expectedSequence3, actualSequence3);
        System.assertEquals(expectedSequence4, actualSequence4); 
        System.assertEquals(expectedChainName1, actualChainName1);
        System.assertEquals(expectedChainName2, actualChainName2);
        System.assertEquals(expectedChainName3, actualChainName3);
        System.assertEquals(expectedChainName4, actualChainName4); 
    } 
    
    static testMethod void callingEnqueueSuccessfullyCallEnqueueImp() {
        // arrange
        String theChainName = 'testChain';
        Id theId = '000000000000000AAA'; 
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.BrokerStub.class.getName() );
        Boolean actualBeforeFlag = BrokerTest.flagEnqueueImpl;
        
        // act  
        Broker.enqueue(theChainName, theId); 
        
        // assert
        Boolean expectedBeforeFlag = false;
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = BrokerTest.flagEnqueueImpl;
        System.assertEquals(expectedAfterFlag , actualAfterFlag); 
        System.assertEquals(expectedBeforeFlag , actualBeforeFlag); 
    }
    
    
    
    static testMethod void callingEnqueueSuccessfullyCallEnqueueImpAndCreatesDocument() {
        // arrange
        String theChainName = 'testChain';
        Blob theData = Blob.valueOf('balls'); 
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.BrokerStub.class.getName() );
        Boolean actualBeforeFlag = BrokerTest.flagEnqueueImpl;
        List<Document> documentsBefore = [SELECT id FROM Document];
        Integer actualSizeBefore = documentsBefore.size();
        
        // act  
        Broker.enqueue(theChainName, theData); 
        
        // Assemble 
        List<Document> documentsAfter = [SELECT id FROM Document];
        Integer actualSizeAfter = documentsAfter.size();
        
        
        // assert
        Boolean expectedBeforeFlag = false;
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = BrokerTest.flagEnqueueImpl;
        System.assertEquals(expectedAfterFlag , actualAfterFlag); 
        System.assertEquals(expectedBeforeFlag , actualBeforeFlag);
        
        Integer expectedSizeBefore = 0;
        Integer expectedSizeAfter = 1;
        System.assertEquals(expectedSizeBefore , actualSizeBefore); 
        System.assertEquals(expectedSizeAfter , actualSizeAfter); 
        } 
        
        static testMethod void callingStartSuccessfullyCallsStartImp() {
        // arrange 
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.BrokerStub.class.getName() );
        Boolean actualBeforeFlag = BrokerTest.flagStartImpl;
        
        // act  
        Broker.start(); 
        
        // assert
        Boolean expectedBeforeFlag = false;
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = BrokerTest.flagStartImpl;
        System.assertEquals(expectedAfterFlag , actualAfterFlag); 
        System.assertEquals(expectedBeforeFlag , actualBeforeFlag); 
    } 
    
    
    
    static testMethod void callingWrapNotificationsCorrectlyWrapsNotificationsInPersistentDatas() {
        // arrange 
        Map<String,Object> notification1 = new Map<String,Object> { 
            'id' => '1'
        }; 
        
        Map<String,Object> notification2 = new Map<String,Object> { 
            'id' => '2'
        }; 
        
        List<Map<String,Object>> notifications = new List<Map<String,Object>> { notification1, notification2 };
        
        // act  
        List<PersistentData__c> persistentDatas = Broker.wrapNotifications( notifications );
        
        // assemble 
        Integer actualSize = persistentDatas.size();
        
        Boolean isId1 = false; 
        Boolean isId2 = false; 
        Boolean isBuffered = true; 
        for (PersistentData__c persistentData : persistentDatas) {
            Map<String,Object> notification = (Map<String,Object>)System.Json.deserializeUntyped(persistentData.Notification__c);
            String theId = (String) notification.get('id');
            if (theId == '1') {
                isId1 = true; 
            }
            if (theId == '2') {
                isId2 = true; 
            }
            if ( persistentData.Status__c != 'Buffer') {
                isBuffered = false; 
            }
        }
        
        // assert
        Integer expectedSize = notifications.size();
        System.assertEquals(expectedSize , actualSize); 
        
        System.assert(isId1);
        System.assert(isId2); 
        System.assert(isBuffered); 
    } 
    
    
    static testMethod void callingMarkHelperCorrectlSetsCountOnNotificationWhenMarkCountIncrementsTo2() {
        // arrange 
        Integer markCount = 1;
        Map<String,Object> notificationIn0 = new Map<String,Object> { 
            'id' => '0',
            'eda__markCount' => markCount
        }; 
        
        Map<String,Object> notificationOut1 = new Map<String,Object> { 
            'id' => '1'
        }; 
        
        Map<String,Object> notificationOut2 = new Map<String,Object> { 
            'id' => '2'
        }; 
        
        Map<String,Object> notificationOut3 = new Map<String,Object> { 
            'id' => '3'
        };
        
        List<Map<String,Object>> notificationsOut = new List<Map<String,Object>> { notificationOut1, notificationOut2, notificationOut3 };
        
        // act  
        Broker.markHelper(notificationIn0, notificationsOut);
        
        // assemble 
        Integer actualCount = (Integer) notificationIn0.get('eda__count');
        
        // assert
        Integer expectedCount = notificationsOut.size();
        System.assertEquals(expectedCount , actualCount); 
    } 
    
    static testMethod void callingMarkHelperDoesNotSetCountOnNotificationWhenMarkCountIncrementsToOtherThan2() {
        // arrange 
        Integer markCount = 0; // will not increment to 2
        Map<String,Object> notificationIn0 = new Map<String,Object> { 
            'id' => '0',
            'eda__markCount' => markCount
        }; 
        
        List<Map<String,Object>> notificationsOut = new List<Map<String,Object>>();
        
        // act  
        Broker.markHelper(notificationIn0, notificationsOut);
        
        // assemble 
        Integer actualCount = (Integer) notificationIn0.get('eda__count');
        
        // assert
        Integer expectedCount = null;
        System.assertEquals(expectedCount , actualCount); 
    } 
    
    static testMethod void callingMarkHelperDoesNotSetCountOnNotificationWhenMarkCountIsNull() {
        // arrange 
        Map<String,Object> notificationIn0 = new Map<String,Object> { 
            'id' => '0' 
            // 'eda__markCount' => markCount // Not specified / key will return null
        }; 
        
        List<Map<String,Object>> notificationsOut = new List<Map<String,Object>>();
        
        // act  
        Broker.markHelper(notificationIn0, notificationsOut);
        
        // assemble 
        Integer actualCount = (Integer) notificationIn0.get('eda__count');
        
        // assert
        Integer expectedCount = null;
        System.assertEquals(expectedCount , actualCount); 
    }
    
    
    //TODO :: write test for this when you (NReid) understand this ( cant remember right now)
    // if (count == 0) Database.delete(new List<Id>{(Id)notification.get('eda__gateGroupId')}); //tidy up split of 0
    
    
    /*
    // Bug with Salesforce ::
    // we cannot legitimately test for data purges - See Andy Fawcett's stackexchange comment
    // http://salesforce.stackexchange.com/questions/27180/database-emptyrecyclebin-exhibits-unexpected-behaviour
    static testMethod void callingPurgePersistentDatasCorrectlyRemovesDeletedPersistentDatasFromRecycle() {
        // arrange 
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>{
            new PersistentData__c( Status__c = 'Buffer', Notification__c = '1'),
            new PersistentData__c( Status__c = 'Buffer', Notification__c = '2')
        };
        insert persistentDatas;
        
        List<PersistentData__c> persistentDatasBeforeDelete = [SELECT Id FROM PersistentData__c WHERE IsDeleted = false ALL ROWS];
        Integer actualBeforeDeleteCount = persistentDatasBeforeDelete.size(); 
        
        delete persistentDatas;
        
        List<PersistentData__c> persistentDatasAfterDelete = [SELECT Id FROM PersistentData__c WHERE IsDeleted = true ALL ROWS];
        Integer actualAfterDeleteCount = persistentDatasAfterDelete.size(); 
        
        // act 
        Broker.purgePersistentDatas();
        
        // assemble
        List<PersistentData__c> persistentDatasAfterPurge = [SELECT Id , IsDeleted, Notification__c FROM PersistentData__c ALL ROWS];
        Integer actualAfterPurgeCount = persistentDatasAfterPurge.size(); 
        
        // assert
        Integer expectedBeforeDeleteCount = 2; 
        Integer expectedAfterDeleteCount = 2;
        Integer expectedAfterPurgeCount = 0;
        System.assertEquals(expectedBeforeDeleteCount , actualBeforeDeleteCount); 
        System.assertEquals(expectedAfterDeleteCount , actualAfterDeleteCount ); 
        // Note : Database.emptyRecyleBin() does not work under a test enviroment : 
        // System.assertEquals(expectedAfterPurgeCount , actualAfterPurgeCount ); 
    } 
    */
    
    
    /*
    // TODO : this test will fail until we resolve issue #178
    // Since the different engines fundamentally persist at different points
    // it will be difficult to do the try catch in the base class - each 
    // broker implementation should  implement the try catch around the resolve 
    //  and if exception then 1. no deletion of input persistentData  
    // 2. no persistence of returned persistedDatas collection 3. save 
    // error against input persisted data's Message__c
    static testmethod void testDodgyProcess() {
        // arrange
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        // arrange chain
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        
        // arrange steps
        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = markProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = terminateProcess.Id);
        insert stepA1;
        insert stepA2;
        
        //simulate dodgy process by deleting reference
        markProcess.FullyQualifiedClassName__c = null;
        update markProcess;
        
        insert new BrokerSettings__c(BrokerClassName__c = BatchBroker.class.getName() );
        
        // act
        Test.startTest();
        Broker.enqueue('testChain', '000000000000000AAA');
        Test.stopTest();
        
        // arrange
        PersistentData__c persistentData = [SELECT Id, Message__c FROM PersistentData__c];
        
        // asserts
        String expectedMessage = 'class missing';
        String actualMessage = persistentData.Message__c;
        System.assert(actualMessage.contains(expectedMessage));
    }
    */
        
    static testMethod void testMalformedNotificationThrowsSystemJsonException() {
        // arrange
        PersistentData__c persistentData = new PersistentData__c(Notification__c = '{"malformed":....}');
        insert persistentData;
        
        // act
        BrokerStub broker = new BrokerStub();
        List<PersistentData__c> persistentDatas = broker.execute(persistentData);
        
        // assemble 
        PersistentData__c persistentDataActual = [SELECT id, Message__c FROM PersistentData__c WHERE id = :persistentData.Id];
        
        // assert
        String actualMessage = persistentDataActual.Message__c;
        String expectedMessage = 'Could not deserialize json';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testMissingSequenceThrowsExpectedException() {
        // arrange
        PersistentData__c persistentData = new PersistentData__c(Notification__c = '{"not_sequence": 0}');
        insert persistentData;
        
        // act
        BrokerStub broker = new BrokerStub();
        List<PersistentData__c> persistentDatas = broker.execute(persistentData);
        
        // assemble 
        PersistentData__c persistentDataActual = [SELECT id, Message__c FROM PersistentData__c WHERE id = :persistentData.Id];
        
        // assert
        String actualMessage = persistentDataActual.Message__c;
        String expectedMessage = 'sequence';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testNoChainStepThrowsQueryException() {
        // arrange (note there is no ChainStep__c in database!)
        PersistentData__c persistentData = new PersistentData__c(Notification__c = '{"eda__chainName": "", "eda__sequence": 0}');
        insert persistentData;
        
        // act
        BrokerStub broker = new BrokerStub();
        List<PersistentData__c> persistentDatas = broker.execute(persistentData);
        
        // assemble 
        PersistentData__c persistentDataActual = [SELECT id, Message__c FROM PersistentData__c WHERE id = :persistentData.Id];
        
        // assert
        String actualMessage = persistentDataActual.Message__c;
        String expectedMessage = 'ChainStep';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
        
        
    static testMethod void testProcessWithoutClassThrowsThrowsExpectedException() {
        // arrange 
        Process__c terminateProcess = Processes.generateOne(Terminate.class);

        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;

        ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        terminateProcess.FullyQualifiedClassName__c = 'lalala';
        update terminateProcess; //pretend we deleted the class
        
        // act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();
        
        // assemble
        PersistentData__c persistentData = [SELECT Message__c FROM PersistentData__c];
        
        // assert
        String actualMessage = persistentData.Message__c;
        String expectedMessage = 'class missing';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    
    static testMethod void testNonProcessPluginThrowsTypeException() {
        // arrange 
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;

        ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        terminateProcess.FullyQualifiedClassName__c = 'Account';
        update terminateProcess; //this is definitely not a Process.Plugin
        
        // act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();
        
        // assert
        PersistentData__c persistentData = [SELECT Message__c FROM PersistentData__c];
        String actualMessage = persistentData.Message__c;
        String expectedMessage = 'interface';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
}