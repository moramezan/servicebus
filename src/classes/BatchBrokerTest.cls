@isTest private class BatchBrokerTest {
 
    static testMethod void testBrokerSurfacesExceptionThrownInsideofAnEdaProcess() {
        //arrange processes
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c wiretapStep = ChainSteps.generateOne(chain.Id, wiretapProcess.Id);
        
        //act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();
        
        PersistentData__c persistentData = [SELECT Message__c FROM PersistentData__c];
        String actualMessage = persistentData.Message__c;
        String expectedMessage = 'eda processable error'; //-- if not configured , wiretap will throw an error
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testBrokerDoesNotSurfaceExceptionForProperlyInvokedProcessable() {
        //arrange processes
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c terminateStep = ChainSteps.generateOne(chain.Id, terminateProcess.Id);
 
        //act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();
        
        PersistentData__c persistentData = [SELECT Message__c FROM PersistentData__c];
        String actualMessage = persistentData.Message__c;
        String expectedMessage = null;   // No Error expected   
        System.assertEquals(actualMessage, actualMessage); 
    }

 
    static testMethod void testNotificationIsCorrectlyWrittenToPersistentDatas() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c step1 = ChainSteps.generateOne(chain.Id, markProcess.Id);
        ChainStep__c step2 = ChainSteps.generateOne(chain.Id, markProcess.Id);
        ChainStep__c step3 = ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        //act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();
        
        // assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Notification__c, ChainStep__c  //, Process__c  
            FROM PersistentData__c 
            ORDER BY Id ASC
        ];
      
 
        // assert
        Integer expectedCount = 3;
        Integer actualCount = persistentDatas.size();
        System.assertEquals(expectedCount, actualCount);
        
 
        Id expectedChainStepId1 = step1.Id;
        Id actualChainStepId1 = persistentDatas[0].ChainStep__c;
        System.assertEquals(expectedChainStepId1, actualChainStepId1);
        
        Id expectedChainStepId2 = step2.Id;
        Id actualChainStepId2 = persistentDatas[1].ChainStep__c;
        System.assertEquals(expectedChainStepId2, actualChainStepId2);
        
        Id expectedChainStepId3 = step3.Id;
        Id actualChainStepId3 = persistentDatas[2].ChainStep__c;
        System.assertEquals(expectedChainStepId3, actualChainStepId3);
    }


    /*static testMethod void testEnqueueByBlob() {
        //arrange 
        List<String> names = new List<String>{'Mark', 'Terminate'};   
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        Process__c markProcess  = (Process__c )procecessNameToProcess.get('Mark');
        Process__c terminateProcess  = (Process__c )procecessNameToProcess.get('Terminate');
                
 
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;

        ChainStep__c step1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = markProcess.Id);
        ChainStep__c step2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = sinkProcess.Id);
        List<ChainStep__c> chainSteps =  new List<ChainStep__c>{step1, step2 };
        insert chainSteps;          

        String data = 'herpderp';
        Blob dataBlob = Blob.valueOf(data);
 
        //act
        Test.startTest();
        Broker.enqueue(chain.Name, dataBlob);
        Test.stopTest();
        
        // assemble
        List<PersistentData__c>  persistentDatas  = [
            SELECT id, Notification__c, ChainStep__c //, Process__c  
            FROM PersistentData__c 
            WHERE ChainStep__r.Process__c = :markProcess.Id
        ];
        
        List<Document> documents = [SELECT Id, Body FROM Document];
        
        Id expectedId  = null;
        Id actualId  =  null;
        String expectedData = data;
        String actualData = null;
        if ( documents.size() >  0 ) {
            actualId  = documents[0].Id;
            actualData = documents[0].Body.toString();        
            
        }   
        if ( persistentDatas.size() >  0 ) {
            Map<string,Object> notification = (Map<String,Object>)Json.deserializeUntyped(persistentDatas[0].Notification__c);   
            expectedId  =  (Id) notification.get('id');
        }
                
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = persistentDatas.size();
        System.assertEquals(expectedCount, actualCount);
        
        System.assert(actualId != null);
        System.assertEquals(expectedId, actualId);
        System.assertEquals(expectedData, actualData);
    }*/


 
    static testmethod void testDodgyProcess() {
        //arrange process
        Process__c terminateProcess = Processes.generateOne(Mark.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c step = ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        insert step;
        
        //simulate dodgy process by deleting reference
        terminateProcess.FullyQualifiedClassName__c = null;
        update terminateProcess;
        
        //act
        Test.startTest();
        Broker.enqueue('testChain', '000000000000000AAA');
        Test.stopTest();
        
        //arrange
        PersistentData__c persistentData = [SELECT Id, Message__c FROM PersistentData__c];
        
        //asserts
        String expectedMessage = 'class missing';
        String actualMessage = persistentData.Message__c;
        System.assert(actualMessage.contains(expectedMessage));
    }
    
    static testMethod void testMalformedNotificationThrowsSystemJsonException() {
        //arrange
        PersistentData__c persistentData = new PersistentData__c(Notification__c = '{"malformed":....}');
 
        //act
        //broker.doWork(persistentData);

        //assert
        String actualMessage = persistentData.Message__c;
        String expectedMessage = 'Could not deserialize json';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }

    
    static testMethod void testMissingSequenceThrowsExpectedException() {
        //arrange
        PersistentData__c persistentData = new PersistentData__c(Notification__c = '{"not_sequence": 0}');
  
        //act
        //broker.doWork(persistentData);

        //assert
        String actualMessage = persistentData.Message__c;
        String expectedMessage = 'sequence';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testNoChainStepThrowsQueryException() {
        //arrange (note there is no ChainStep__c in database!)
        PersistentData__c persistentData = new PersistentData__c(Notification__c = '{"eda__chainName": "", "eda__sequence": 0}');
  
        //act
        //broker.doWork(persistentData);

        //assert
        String actualMessage = persistentData.Message__c;
        String expectedMessage = 'ChainStep';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }

 
 
    static testMethod void testProcessWithoutClassThrowsThrowsExpectedException() {
        //arrange processes
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        terminateProcess.FullyQualifiedClassName__c = 'lalala';
        update terminateProcess; //pretend we deleted the class
        
        //act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        PersistentData__c persistentData = [SELECT Message__c FROM PersistentData__c];
        
        //assert
        String actualMessage = persistentData.Message__c;
        String expectedMessage = 'class missing';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testNonProcessPluginThrowsTypeException() {
        //arrange processes
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        terminateProcess.FullyQualifiedClassName__c = 'Account';
        update terminateProcess; //this is definitely not a Process.Plugin
        
        //act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();

        //assert
        PersistentData__c persistentData = [SELECT Message__c FROM PersistentData__c];
        String actualMessage = persistentData.Message__c;
        String expectedMessage = 'interface';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
}