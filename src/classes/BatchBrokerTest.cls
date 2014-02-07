@isTest public class BatchBrokerTest {
 
    static testMethod void callingMarkEligiblePersistentDatasAsProcessingCorrectlySetsStatusAsProcessing() {
        //arrange                                                                     
        Integer queryLimit = 2;
        
        List<PersistentData__c> persistentDatas =  new List<PersistentData__c>{
            new PersistentData__c(Status__c = 'Buffer'),
            new PersistentData__c(Status__c = 'Buffer'),
            new PersistentData__c(Status__c = 'Buffer')  
        };
        insert persistentDatas;
        
        //act  
        BatchBroker broker = new BatchBroker();                                                                                                                                                                   
        Set<Id> persistentDataIds =  broker.markEligiblePersistentDatasAsProcessing(queryLimit) ;
        
        // assert
        Integer actualCount = persistentDataIds.size();
        Integer expectedCount = 2;
        System.assertEquals(expectedCount, actualCount); 
    }  

    static testMethod void callingGetQueryLimitReturnsExpectedValue01() {
        //arrange                                                                     
        Integer fuckedLimit = 2;
        
        List<PersistentData__c> fuckedPersistentDatas =  new List<PersistentData__c>{
            new PersistentData__c(Status__c = 'Processing'),
            new PersistentData__c(Status__c = 'Processing') 
        };
        insert fuckedPersistentDatas;
    
        List<PersistentData__c> reprocessPersistentDatas =  new List<PersistentData__c>{
            new PersistentData__c(Status__c = 'Reprocess'),
            new PersistentData__c(Status__c = 'Reprocess') 
        };
        insert reprocessPersistentDatas;
 
        //act                                                                                                                                                                    
        Integer actualCount =   BatchBroker.getQueryLimit(fuckedLimit);
        
        // assert
        Integer expectedCount = 2;
        System.assertEquals(expectedCount, actualCount); 
    } 

    
    
     static testMethod void callingGetQueryLimitReturnsExpectedValue02() {
        //arrange                                                                     
        Integer fuckedLimit = 2;
        
        List<PersistentData__c> fuckedPersistentDatas =  new List<PersistentData__c>{
            new PersistentData__c(Status__c = 'Processing'),
            new PersistentData__c(Status__c = 'Processing') 
        };
        insert fuckedPersistentDatas;
    
        List<PersistentData__c> reprocessPersistentDatas =  new List<PersistentData__c>();
        insert reprocessPersistentDatas; // Zero Reprocess
 
        //act                                                                                                                                                                    
        Integer actualCount =   BatchBroker.getQueryLimit(fuckedLimit);
        
        // assert
        Integer expectedCount = 0;
        System.assertEquals(expectedCount, actualCount); 
    } 
    
    
    
     static testMethod void callingGetQueryLimitReturnsExpectedValue03() {
        //arrange                                                                     
        Integer fuckedLimit = 3;
        
        List<PersistentData__c> fuckedPersistentDatas =  new List<PersistentData__c>{
            new PersistentData__c(Status__c = 'Processing'),
            new PersistentData__c(Status__c = 'Processing') 
        };
        insert fuckedPersistentDatas;
    
        List<PersistentData__c> reprocessPersistentDatas =  new List<PersistentData__c>();
        insert reprocessPersistentDatas; // Zero Reprocess
 
        //act                                                                                                                                                                    
        Integer actualCount =   BatchBroker.getQueryLimit(fuckedLimit);
        
        // assert
        Integer expectedCount = 1;
        System.assertEquals(expectedCount, actualCount); 
    } 

    
       
       
    static testMethod void canCorrectlyResolveAndPersistPersistentDatas() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
          
        //arrange chain
        String  chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
 
                      
        //arrange steps
        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        Integer sequenceA3 = 3;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = subscribeProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = markProcess.Id);
        ChainStep__c stepA3 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA3,Process__c = terminateProcess.Id);
        insert stepA1;
        insert stepA2;
        insert stepA3;


        List<PersistentData__c> persistentDatas =  new List<PersistentData__c>{
            new PersistentData__c(Notification__c = '{ "eda__chainName": "' + chainA.Name + '", "eda__sequence": ' + sequenceA1 + '}'),
            new PersistentData__c(Notification__c = '{ "eda__chainName": "' + chainA.Name + '", "eda__sequence": ' + sequenceA2 + '}')
        };
            
        //act
        BatchBroker broker = new BatchBroker();
        broker.resolveAndPersist( persistentDatas);

        // assemble
        List<PersistentData__c> persistentDatasAfter = [
            SELECT id, Notification__c, ChainStep__c, Process__c 
            FROM PersistentData__c
        ];

        Boolean flagSequence01 = false;
        Boolean flagSequence02 = false;
        Boolean flagChainNameA = true;
        Id actualChainStepId01;
        Id actualChainStepId02;    
        Id actualProcessId01;
        Id actualProcessId02;
        for (PersistentData__c persistentData : persistentDatasAfter) {
            Map<String,Object> notification = (Map<String,Object>)System.Json.deserializeUntyped(persistentData.Notification__c);
            String notificationChainName  = (String) notification.get('eda__chainName');
            Integer notificationSequence  = (Integer) notification.get('eda__sequence'); 
            if (notificationChainName != chainNameA) {
                flagChainNameA = false;
            }
            if (notificationSequence == (sequenceA1 + 1))  {
                flagSequence01 = true;
                actualChainStepId01 =  persistentData.ChainStep__c;
                actualProcessId01   =  persistentData.Process__c;         
            }
            if (notificationSequence == (sequenceA2 + 1))  {
                flagSequence02 = true;
                actualChainStepId02 =  persistentData.ChainStep__c;    
                actualProcessId02   =  persistentData.Process__c;
            }
        }
        
        // assert
        Integer expectedCount = 2;
        Integer actualCount = persistentDatasAfter.size();
        System.assertEquals(expectedCount, actualCount);

        System.assert(flagChainNameA );
        System.assert(flagSequence01 );
        System.assert(flagSequence02 );

        Id expectedChainStepId01 = stepA2.Id;
        Id expectedChainStepId02 = stepA3.Id ;
        Id expectedProcessId01   = markProcess.Id;
        Id expectedProcessId02   = terminateProcess.Id;    
        System.assertEquals(expectedChainStepId01, actualChainStepId01);
        System.assertEquals(expectedChainStepId02, actualChainStepId02); 
        System.assertEquals(expectedProcessId01  , actualProcessId01  );
        System.assertEquals(expectedProcessId02  , actualProcessId02  );
    }     
 
    static testMethod void callingEnqueueSuccessfullyCallEnqueueImp() {
        //arrange 
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        String  chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;

        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = markProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = terminateProcess.Id);
        insert stepA1;
        insert stepA2;
  
 
        insert  new BrokerSettings__c(BrokerClassName__c  = BatchBroker.class.getName() );
 
        //act 
        Test.startTest();
        Broker.enqueue(chainNameA, '000000000000000AAA'); 
        Test.stopTest();
        
        // assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, isDeleted 
            FROM PersistentData__c 
            WHERE isDeleted =  false
            ALL ROWS
        ];

        Integer actualCount = persistentDatas.size();
        
        // assert
        Integer expectedCount = 1; 
        System.assertEquals(expectedCount , actualCount);  
 
     } 
 
 
    static testMethod void callingEnqueueWithInternallyFailingPluginSuccessfullyWritesErrorMessageToPersistentData() {
        //arrange 
        Process__c failureProcess = Processes.generateOne(FailurePlugin.class);

        String  chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;

        Integer sequenceA1 = 1;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = failureProcess.Id);
        insert stepA1;

        insert  new BrokerSettings__c(BrokerClassName__c  = BatchBroker.class.getName() );
 
        //act 
        Test.startTest();
        Broker.enqueue(chainNameA, '000000000000000AAA'); 
        Test.stopTest();
        
        // assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, Message__c, isDeleted 
            FROM PersistentData__c 
            WHERE isDeleted =  false
            ALL ROWS
        ];
        Integer actualCount = persistentDatas.size();
        
        // assert
        Integer expectedCount = 1; 
        System.assertEquals(expectedCount , actualCount); 
        
        String expectedProcessName = FailurePlugin.class.getName();
        System.assertEquals(expectedProcessName, persistentDatas[0].Process__r.Name);

        String expectedMessage = FailurePlugin.FailureMessage;
        System.assertEquals(expectedMessage, persistentDatas[0].Message__c  );
     } 

    static testMethod void callingBrokerStartSuccessfullyCallsStartImp() {
        //arrange 
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        String  chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;

        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = markProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = terminateProcess.Id);
        insert stepA1;
        insert stepA2;
  
 
        insert  new BrokerSettings__c(BrokerClassName__c  = BatchBroker.class.getName() );

        // scenario:
        // resolved state , assume manual intervention to set status to 'Reprocess'
        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainNameA,
            'eda__sequence' => 1,    // not zero !!!
            'id' => '000000000000000AAA'
        };
        PersistentData__c persistentData = new PersistentData__c(
            ChainStep__c = stepA1.Id,
            Status__c = 'Reprocess',
            Notification__c = Json.serializePretty(notification)
        );
        insert persistentData;
        
 
        //act 
        Test.startTest();
        Broker.start(); 
        Test.stopTest();
        
        // assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, isDeleted 
            FROM PersistentData__c 
            WHERE isDeleted =  false
            ALL ROWS
        ];

        Integer actualCount = persistentDatas.size();
        
        // assert
        Integer expectedCount = 1; 
        System.assertEquals(expectedCount , actualCount);  
     } 
 
}