@isTest private class PublishTest {

    static testMethod void canDetermineConfigurable() {
        //arrange
        String  className  = 'Publish';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        
        //act
        String actualConfiguration = processes[0].Configurable__c;
        
        //assert
        String expectedConfiguration = Schema.SObjectType.PublishConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
    
    static testMethod void testBoomerangDropped() {
        EventType__c eventType = new EventType__c(Name = 'ready');
        insert eventType;
        
        Process__c process = new Process__c(Name = 'Subscribe');
        insert process;
        
        PublishConfiguration__c pubConfig = new PublishConfiguration__c(EventType__c = eventType.Id);
        insert pubConfig;
        
        SubscribeConfiguration__c subConfig = new SubscribeConfiguration__c(EventType__c = eventType.Id);
        insert subConfig;
        
        Chain__c target = new Chain__c(Name = 'target');
        insert target;
        
        ChainStep__c subscribe = new ChainStep__c(Chain__c = target.Id, Sequence__c = 1, Process__c = process.Id, Configuration__c = subConfig.Id);
        insert subscribe;
        
        subscribe = [SELECT Configuration__c FROM ChainStep__c WHERE Id = :subscribe.Id];
        
        Database.update(new SubscribeConfiguration__c(
            Id = subscribe.Configuration__c,
            EventType__c = eventType.Id
        ));
        
        Map<String,Object> notification = new Map<String,Object>{
            'eda__configuration' => pubConfig.Id,
            'eda__boomerangChainStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Publish branch = new Publish();
        List<Map<String,Object>> notifications = Utility.convert(branch.invoke(new Process.PluginRequest(notification)));
        
        //should return one for sub, one for passthru
        Integer expectedSize = 2;
        Integer actualSize = notifications.size();
        System.assertEquals(expectedSize, actualSize);
        
        //first one is for subscriber
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)notifications[0].get('eda__boomerangChainStepIds');
        System.assertEquals(expectedIds, actualIds);
        
        //second one is original/passthru
        expectedIds = new List<Id>{'000000000000000AAA'};
        actualIds = (List<Object>)notifications[1].get('eda__boomerangChainStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testMethod void testUnconfiguredPublishProcessThrowsException() {
        //arrange
        Process__c process = new Process__c(Name = 'Publish');
        insert process;
        
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Process__c = process.Id, Sequence__c = 1);
        insert chainStep;
        
        PublishConfiguration__c config = new PublishConfiguration__c();
        insert config;
        
        Publish publish = new Publish();
        Map<String,Object> notification = new Map<String,Object>{'eda__chainName' => 'TestChain', 'eda__sequence' => 1, 'eda__configuration' => config.Id};
        Process.PluginRequest request = new Process.PluginRequest(notification);
        
        //act
        Boolean thrown = false;
        try {publish.invoke(request);}
        catch (Publish.PublishException e) {thrown = true;}
        
        //assert
        System.assert(thrown);
    }
    
    static testMethod void testNoSubscribersStillReturnsOneNotification() {
        //arrange
        List<String> names = new List<String>{'Publish'};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
       Process__c process = (Process__c )procecessNameToProcess.get('Publish');
        
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
        insert chainStep;
        
        PublishConfiguration__c publishConfiguration = [SELECT Id FROM PublishConfiguration__c];
        publishConfiguration.EventType__c = eventType.Id;
        update publishConfiguration;
        
        String data = '{"eda__chainName":"TestChain","eda__sequence":1,"eda__configuration":"' + publishConfiguration.Id + '"}';
        Map<String,Object> notification = (Map<String,Object>)System.Json.deserializeUntyped(data);
        Publish publish = new Publish();
        
        //act
        Process.PluginResult results = publish.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> notifications = Utility.convert(results);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = notifications.size();
        System.assertEquals(expectedSize, actualSize);
        
        Integer expectedData = data.length();
        Integer actualData = System.Json.serialize(notifications[0]).length();
        System.assertEquals(expectedData, actualData);
    }
    
    static testMethod void testSubscribersAffectNotificationsReturned() {
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        List<String> names = new List<String>{'Subscribe', 'Publish'};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        
        //publish process
       Process__c publish = (Process__c )procecessNameToProcess.get('Publish');
        
        //publish chains and steps
        Chain__c publisher = new Chain__c(Name = 'Publisher');
        insert publisher;
        
        ChainStep__c publisherStep = new ChainStep__c(Chain__c = publisher.Id, Sequence__c = 1, Process__c = publish.Id);
        insert publisherStep;
        
        publisherStep = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :publisherStep.Id];
        
        Database.update(new PublishConfiguration__c(
            Id = publisherStep.Configuration__c,
            EventType__c = eventType.Id
        ));
        
        //subsribe process
        Process__c subscribe = (Process__c )procecessNameToProcess.get('Subscribe');
       
       
        //subscribe chains and steps
        Chain__c subscriber1 = new Chain__c(Name = 'Subscriber1');
        insert subscriber1;
        
        ChainStep__c subscriber1step = new ChainStep__c(Chain__c = subscriber1.Id, Sequence__c = 1, Process__c = subscribe.Id);
        insert subscriber1step;
        
        subscriber1step = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :subscriber1step.Id];
        
        Database.update(new SubscribeConfiguration__c(
            Id = subscriber1step.Configuration__c,
            EventType__c = eventType.Id
        ));
        
        Chain__c subscriber2 = new Chain__c(Name = 'Subscriber2');
        insert subscriber2;
        
        ChainStep__c subscriber2step = new ChainStep__c(Chain__c = subscriber2.Id, Sequence__c = 1, Process__c = subscribe.Id);
        insert subscriber2step;
        
        subscriber2step = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :subscriber2step.Id];
        
        Database.update(new SubscribeConfiguration__c(
            Id = subscriber2step.Configuration__c,
            EventType__c = eventType.Id
        ));
        
        //arrange
        Map<String,Object> notification = new Map<String,Object>{'eda__chainName' => 'Publisher', 'eda__sequence' => 1, 'eda__configuration' => publisherStep.Configuration__c};
        
        //act
        Publish process = new Publish();
        Process.PluginResult results = process.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> notifications = Utility.convert(results);
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = notifications.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContaingStausEqUnknown() {
        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
 
        // Processes :: Publish process not defined
        String  classNameWiretap  = 'Wiretap';
        List<String> names = new List<String>{classNameWiretap};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        
        // Chain A
        ChainStep__c chainStepA1 = new ChainStep__C(Chain__c = chainA.Id, Process__c = ((Process__c )procecessNameToProcess.get('Wiretap')).Id, Sequence__c  = 1);
        ChainStep__c chainStepA2 = new ChainStep__C(Chain__c = chainA.Id, Process__c = ((Process__c )procecessNameToProcess.get('Wiretap')).Id, Sequence__c = 2);   

        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth();
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualUnknownCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            chainIdToDescription.put(PublishHealth.ChainId, PublishHealth.Detail);
            if (PublishHealth.Status == 'Unknown') {
                actualUnknownCount++;
            }         
        }
        
        // Assert :
        Integer expectedCount = 1;
        Integer actualCount = PublishHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedUnknownCount = 1;
        System.assertEquals(expectedUnknownCount, actualUnknownCount);
        
        String actualUnknown = chainIdToDescription.get(chainA.Id);
        String expectedUnknown = 'Cannot resolve Id of Publish process';
        System.assertEquals(expectedUnknown, actualUnknown);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContaningStatusEqOk() {
        // Arrange :
        Chain__c chainSubscribe = new Chain__c(Name = 'Subscribe');
        insert chainSubscribe;
        Chain__c chainZ = new Chain__c(Name = 'ChainZ');
        insert chainZ;

        String  classNameWiretap  = 'Wiretap';
        String  classNamePublish  = 'Publish';
        String  classNameSubscribe  = 'Subscribe'; 
        List<String> names = new List<String>{classNameWiretap, classNamePublish, classNameSubscribe};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        
        // Chain Z - OK : Event is Subscribed
        ChainStep__c chainStepZ1 = new ChainStep__c(Chain__c = chainZ.Id, Process__c = ((Process__c )procecessNameToProcess.get('Publish')).Id, Sequence__c = 1); 
        ChainStep__c chainStepZ2 = new ChainStep__c(Chain__c = chainZ.Id, Process__c = ((Process__c )procecessNameToProcess.get('Wiretap')).Id, Sequence__c = 2);
        insert new List<ChainStep__c>{chainStepZ1, chainStepZ2};
        ChainStep__c chainStepZ3 = new ChainStep__c(Chain__c = chainSubscribe.Id, Process__c = ((Process__c )procecessNameToProcess.get('Subscribe')).Id, Sequence__c = 1); 
        insert new List<ChainStep__c>{chainStepZ3}; 

        // Event
        EventType__c eventTypeSubscribed = new EventType__c(Name = 'an-event-that-IS-Subscribed');
        insert eventTypeSubscribed;

        // Config Subscribe 
        Id SubscribeConfigurationIdZ3 = (Id) [SELECT Id, Configuration__c 
            FROM ChainStep__c 
            WHERE Id = :chainStepZ3.Id LIMIT 1
        ].Configuration__c;
            
        SubscribeConfiguration__c SubscribeConfigurationZ3 = [
            SELECT Id, EventType__c 
            FROM SubscribeConfiguration__c 
            WHERE Id = :SubscribeConfigurationIdZ3
        ];
        
        SubscribeConfigurationZ3.EventType__c = eventTypeSubscribed.Id;
        update SubscribeConfigurationZ3;    
        
        // Config Z1 
        Id configurationIdZ1 = (Id) [
            SELECT Id, Configuration__c 
            FROM ChainStep__c 
            WHERE Id = :chainStepZ1.Id LIMIT 1
        ].Configuration__c;
        
        PublishConfiguration__c PublishConfigurationZ1 = [
            SELECT Id, EventType__c 
            FROM PublishConfiguration__c 
            WHERE Id = :configurationIdZ1
        ];
        
        PublishConfigurationZ1.EventType__c = eventTypeSubscribed.Id;
        update PublishConfigurationZ1;

        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualOkCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            chainIdToDescription.put(PublishHealth.ChainId, PublishHealth.Detail);
            if (PublishHealth.Status == 'Ok') {
                actualOkCount++;
            }
        }
        
        // Assert :
        Integer expectedCount = 1;
        Integer actualCount = PublishHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedOkCount = 1; 
        System.assertEquals(expectedOkCount, actualOkCount);
    }

     static testMethod void callingGetHealthReturnsExpectedListContaningStatusEqWarning() {
        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;

        String  classNameWiretap  = 'Wiretap';
        String  classNamePublish  = 'Publish';
        List<String> names = new List<String>{classNameWiretap, classNamePublish};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }

        // Chain A - Warning : Ok but event Not Subscribed
        ChainStep__c chainStepA1 = new ChainStep__c(Chain__c = chainA.Id, Process__c = ((Process__c )procecessNameToProcess.get('Publish')).Id, Sequence__c = 1); 
        ChainStep__c chainStepA2 = new ChainStep__c(Chain__c = chainA.Id, Process__c = ((Process__c )procecessNameToProcess.get('Wiretap')).Id, Sequence__c = 2);
        insert new List<ChainStep__c>{chainStepA1, chainStepA2};

        // Event
        EventType__c eventTypeNotSubscribed = new EventType__c(Name = 'an-event-not-Subscribed');
        insert eventTypeNotSubscribed;

        // Config A1
        Id configurationIdA1 = (Id) [
            SELECT Id, Configuration__c 
            FROM ChainStep__c 
            WHERE Id = :chainStepA1.Id LIMIT 1
        ].Configuration__c;
    
        PublishConfiguration__c PublishConfigurationA1 = [
            SELECT Id, EventType__c 
            FROM PublishConfiguration__c
            WHERE Id = :configurationIdA1
        ];

        PublishConfigurationA1.EventType__c = eventTypeNotSubscribed.Id;
        update PublishConfigurationA1;

        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualWarningCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            chainIdToDescription.put(PublishHealth.ChainId, PublishHealth.Detail);
            if (PublishHealth.Status == 'Warning') {
                actualWarningCount++;
            } 
        }
        
        // Assert :
        Integer expectedWarningCount = 1;
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String actualDescription = chainIdToDescription.get(chainA.Id);
        String expectedDescription = 'No Subscriber is configured to subscribe';
        System.assert(actualDescription.contains(expectedDescription));
    }

    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoConfig() {
        // Arrange :
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;

        String  classNameWiretap  = 'Wiretap';
        String  classNamePublish  = 'Publish';
        List<String> names = new List<String>{classNameWiretap, classNamePublish};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }

        
        // Chain B - Problem : No Configuration
        ChainStep__c chainStepB1 = new ChainStep__c(Chain__c = chainB.Id, Process__c = ((Process__c )procecessNameToProcess.get('Publish')).Id, Sequence__c = 1);
        ChainStep__c chainStepB2 = new ChainStep__c(Chain__c = chainB.Id, Process__c = ((Process__c )procecessNameToProcess.get('Wiretap')).Id, Sequence__c = 2);
        insert new List<ChainStep__c>{chainStepB1, chainStepB2};

        Id configurationIdB1 = (Id) [
            SELECT Id, Configuration__c 
            FROM ChainStep__c 
            WHERE Id = :chainStepB1.Id LIMIT 1
         ].Configuration__c;
        Database.delete(configurationIdB1);
        
        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualErrorCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            chainIdToDescription.put(PublishHealth.ChainId, PublishHealth.Detail);
            if (PublishHealth.Status == 'Error') {
                actualErrorCount++;
            }     
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = chainIdToDescription.get(chainB.Id);
        String expectedDescription = 'Cannot resolve Publish configuration';
        System.assert(actualDescription.contains(expectedDescription));
    }
         
 
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfig() {
        // Arrange :
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;

        String  classNameWiretap  = 'Wiretap';
        String  classNamePublish  = 'Publish';
        List<String> names = new List<String>{classNameWiretap, classNamePublish};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }

        
        // Chain B - Problem : No Configuration
        ChainStep__c chainStepB1 = new ChainStep__c(Chain__c = chainB.Id, Process__c = ((Process__c )procecessNameToProcess.get('Publish')).Id, Sequence__c = 1);
        ChainStep__c chainStepB2 = new ChainStep__c(Chain__c = chainB.Id, Process__c = ((Process__c )procecessNameToProcess.get('Wiretap')).Id, Sequence__c = 2);       
        insert new List<ChainStep__c>{chainStepB1, chainStepB2};

        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualErrorCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            chainIdToDescription.put(PublishHealth.ChainId, PublishHealth.Detail);
            if (PublishHealth.Status == 'Error') {
                actualErrorCount++; 
            }     
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = chainIdToDescription.get(chainB.Id);
        String expectedDescription = 'No event type defined on Publish configuration';
        System.assert(actualDescription.contains(expectedDescription));
    } 
}