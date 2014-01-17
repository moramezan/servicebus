@isTest private class BrokerTest {

    static testMethod void testNotificationProgressesThroughChain() {
        //arrange processes
        List<String> names = new List<String>{'Mark', 'Sink'};   
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        Process__c noopProcess  = (Process__c )procecessNameToProcess.get('Mark');
        Process__c sinkProcess  = (Process__c )procecessNameToProcess.get('Sink');
                
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c step1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = noopProcess.Id);
        ChainStep__c step2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = noopProcess.Id);
        ChainStep__c step3 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 3, Process__c = sinkProcess.Id);
        insert step1;
        insert step2;
        insert step3;
        
        //arrange notification
        Map<String,Object> notification = new Map<String,Object>{
            'eda__chainName' => chain.Name,
            'eda__sequence' => 0
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
        List<AsyncApexJob> asyncApexJobsAfter = [SELECT  ApexClassId FROM AsyncApexJob];
        Test.stopTest();

        // assert
        Integer expectedExecutions = 2;
        Integer actualExecutions = 0;
        for (AsyncApexJob  asyncApexJob  : asyncApexJobsAfter) {
            actualExecutions++;
        }
        System.assertEquals(expectedExecutions, actualExecutions);
    }
    
    static testMethod void testEnqueueByBlob() {
        //arrange processes
        List<String> names = new List<String>{'Mark', 'Sink'};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        Process__c noopProcess  = (Process__c )procecessNameToProcess.get('Mark');
        Process__c sinkProcess  = (Process__c )procecessNameToProcess.get('Sink');
 
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c step1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = noopProcess.Id);
        ChainStep__c step2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = noopProcess.Id);
        ChainStep__c step3 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 3, Process__c = sinkProcess.Id);
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
        String actualChainName = (String)notification.get('eda__chainName');
        System.assertEquals(expectedChainName, actualChainName);
        
        Decimal expectedSequence = 0;
        Decimal actualSequence = (Decimal)notification.get('eda__sequence');
        System.assertEquals(expectedSequence, actualSequence);
    }
    
    static testmethod void testDodgyProcess() {
        //arrange process
        List<String> names = new List<String>{'Mark'};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        Process__c process  = (Process__c )procecessNameToProcess.get('Mark');
 
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange step
        ChainStep__c step = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
        insert step;
        
        // simulate dodgy process by deleting reference
        process.FullyQualifiedClassName__c = null;
        update process;
        
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
        PersistentData__c pd = new PersistentData__c(Notification__c = '{"malformed":...}');
        insert pd;
        
        //act
        Broker broker = new Broker();
        broker.execute(null, new List<SObject>{pd});
        
        //assert
        pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
        String expectedMessage = 'json';
        String actualMessage = pd.Message__c;
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testMissingSequenceThrowsNullPointerException() {
        //arrange
        PersistentData__c pd = new PersistentData__c(Notification__c = '{"not_sequence": 0}');
        insert pd;
        
        //act
        Broker broker = new Broker();
        broker.execute(null, new List<SObject>{pd});
        
        //assert
        pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
        String expectedMessage = 'Sequence';
        String actualMessage = pd.Message__c;
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testNoChainStepThrowsQueryException() {
        //arrange (note there is no ChainStep__c in database!)
        PersistentData__c pd = new PersistentData__c(Notification__c = '{"eda__chainName": "", "eda__sequence": 0}');
        insert pd;
        
        //act
        Broker broker = new Broker();
        broker.execute(null, new List<SObject>{pd});
        
        //assert
        pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
        String expectedMessage = 'ChainStep';
        String actualMessage = pd.Message__c;
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testStupidProcessThrowsNullPointerException() {
        //arrange (note there is no Process__c in database!)
        List<String> names = new List<String>{'Sink'};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        Process__c process  = (Process__c )procecessNameToProcess.get('Sink');

        
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
        insert chainStep;
        
        process.FullyQualifiedClassName__c = 'lalala';
        update process; //pretend we deleted the class
        
        PersistentData__c pd = new PersistentData__c(Notification__c = '{"eda__chainName": "TestChain", "eda__sequence": 0}');
        insert pd;
        
        //act
        Broker broker = new Broker();
        broker.execute(null, new List<SObject>{pd});
        
        //assert
        pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
        String expectedMessage = 'class missing';
        String actualMessage = pd.Message__c;
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testNonProcessPluginThrowsTypeException() {
        //arrange (note there is no Process__c in database!) 
        List<String> names = new List<String>{'Sink'};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        Process__c process  = (Process__c )procecessNameToProcess.get('Sink');
        
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
        insert chainStep;
        
        process.FullyQualifiedClassName__c = 'Account';
        update process; //this is definitely not a Process.Plugin
        
        PersistentData__c pd = new PersistentData__c(Notification__c = '{"eda__chainName": "TestChain", "eda__sequence": 0}');
        insert pd;
        
        //act
        Broker broker = new Broker();
        broker.execute(null, new List<SObject>{pd});
        
        //assert
        pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
        String expectedMessage = 'interface';
        String actualMessage = pd.Message__c;
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
}