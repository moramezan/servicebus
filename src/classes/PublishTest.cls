@isTest private class PublishTest {

    static testMethod void canDetermineConfigurable() {
        //arrange processes
        Process__c publishProcess = Processes.generateOne(Publish.class);
        
        //act
        String actualConfiguration = publishProcess.Configurable__c;
        
        //assert
        String expectedConfiguration = Schema.SObjectType.PublishConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
    
    static testMethod void testBoomerangDropped() {
        //arrange events
        EventType__c eventType = new EventType__c(Name = 'ready');
        insert eventType;
        
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        
        //arrange publish config
        PublishConfiguration__c pubConfig = new PublishConfiguration__c(
            EventType__c = eventType.Id
        );
        insert pubConfig;
        
        //arrange chain
        Chain__c target = new Chain__c(Name = 'target');
        insert target;
        
        ChainStep__c subscribeStep = ChainSteps.generateOne(target.Id, subscribeProcess.Id);
        
        //arrange subscribe config
        Database.update(new SubscribeConfiguration__c(
            Id = subscribeStep.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        Map<String,Object> parameters = new Map<String,Object>{
            'eda__configuration' => pubConfig.Id,
            'eda__boomerangChainStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Publish branch = new Publish();
        List<Map<String,Object>> parametersList = Utility.convert(branch.invoke(new Process.PluginRequest(parameters)));
        
        //should return one for sub, one for passthru
        Integer expectedSize = 2;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        //first one is for subscriber
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[0].get('eda__boomerangChainStepIds');
        System.assertEquals(expectedIds, actualIds);
        
        //second one is original/passthru
        expectedIds = new List<Id>{'000000000000000AAA'};
        actualIds = (List<Object>)parametersList[1].get('eda__boomerangChainStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testMethod void testUnconfiguredPublishProcessThrowsException() {
        //arrange processes
        Process__c process = Processes.generateOne(Publish.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, process.Id);
        
        PublishConfiguration__c config = new PublishConfiguration__c();
        insert config;
        
        Publish publishPlugin = new Publish();
        Map<String,Object> parameters = new Map<String,Object>{'eda__chainName' => 'TestChain', 'eda__sequence' => 1, 'eda__configuration' => config.Id};
        Process.PluginRequest request = new Process.PluginRequest(parameters);
        
        //act
        Boolean thrown = false;
        try {publishPlugin.invoke(request);}
        catch (Publish.PublishException e) {thrown = true;}
        
        //assert
        System.assert(thrown);
    }
    
    static testMethod void testNoSubscribersStillReturnsOneMessage() {
        //arrange processes
        Process__c process = Processes.generateOne(Publish.class);
        
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, process.Id);
        Database.update(new PublishConfiguration__c(
            Id = chainStep.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        String data = '{"eda__chainName":"TestChain","eda__sequence":1,"eda__configuration":"' + chainStep.ConfigurationId__c + '"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        Publish publishPlugin = new Publish();
        
        //act
        Process.PluginResult results = publishPlugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> parametersList = Utility.convert(results);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        Integer expectedData = data.length();
        Integer actualData = System.Json.serialize(parametersList[0]).length();
        System.assertEquals(expectedData, actualData);
    }
    
    static testMethod void testSubscribersAffectParametersListReturned() {
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c publishProcess = Processes.generateOne(Publish.class);
        
        //arrange publish chains and steps
        Chain__c publisher = new Chain__c(Name = 'Publisher');
        insert publisher;
        
        ChainStep__c publisherStep = ChainSteps.generateOne(publisher.Id, publishProcess.Id);
        Database.update(new PublishConfiguration__c(
            Id = publisherStep.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        //arrange subscribe chains and steps
        Chain__c subscriber1 = new Chain__c(Name = 'Subscriber1');
        insert subscriber1;
        
        ChainStep__c subscriber1step = ChainSteps.generateOne(subscriber1.Id, subscribeProcess.Id);
        Database.update(new SubscribeConfiguration__c(
            Id = subscriber1step.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        Chain__c subscriber2 = new Chain__c(Name = 'Subscriber2');
        insert subscriber2;
        
        ChainStep__c subscriber2step = ChainSteps.generateOne(subscriber2.Id, subscribeProcess.Id);
        Database.update(new SubscribeConfiguration__c(
            Id = subscriber2step.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        //arrange
        Map<String,Object> parameters = new Map<String,Object>{'eda__chainName' => 'Publisher', 'eda__sequence' => 1, 'eda__configuration' => publisherStep.ConfigurationId__c};
        
        //act
        Publish process = new Publish();
        Process.PluginResult results = process.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> parametersList = Utility.convert(results);
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContaingStausEqUnknown() {
        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
 
        // Processes :: Publish process not defined
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        // Chain A
        ChainStep__c chainStepA1 = ChainSteps.generateOne(chainA.Id, wiretapProcess.Id);
        ChainStep__c chainStepA2 = ChainSteps.generateOne(chainA.Id, wiretapProcess.Id);

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

        //arrange processes
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c publishProcess = Processes.generateOne(Publish.class);
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);

        // Chain Z - OK : Event is Subscribed
        ChainStep__c chainStepZ1 = ChainSteps.generateOne(chainZ.Id, publishProcess.Id);
        ChainStep__c chainStepZ2 = ChainSteps.generateOne(chainZ.Id, wiretapProcess.Id);
        ChainStep__c chainStepZ3 = ChainSteps.generateOne(chainSubscribe.Id, subscribeProcess.Id);

        // Event
        EventType__c eventTypeSubscribed = new EventType__c(Name = 'an-event-that-IS-Subscribed');
        insert eventTypeSubscribed;

        // Config Subscribe
        Id SubscribeConfigurationIdZ3 = (Id) [SELECT Id, ConfigurationId__c
            FROM ChainStep__c
            WHERE Id = :chainStepZ3.Id LIMIT 1
        ].ConfigurationId__c;
            
        SubscribeConfiguration__c SubscribeConfigurationZ3 = [
            SELECT Id, EventType__c
            FROM SubscribeConfiguration__c
            WHERE Id = :SubscribeConfigurationIdZ3
        ];
        
        SubscribeConfigurationZ3.EventType__c = eventTypeSubscribed.Id;
        update SubscribeConfigurationZ3;
        
        // Config Z1
        Id configurationIdZ1 = (Id) [
            SELECT Id, ConfigurationId__c
            FROM ChainStep__c
            WHERE Id = :chainStepZ1.Id LIMIT 1
        ].ConfigurationId__c;
        
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

        //arrange proceses
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c publishProcess = Processes.generateOne(Publish.class);
        
        // Chain A - Warning : Ok but event Not Subscribed
        ChainStep__c chainStepA1 = ChainSteps.generateOne(chainA.Id, publishProcess.Id);
        ChainStep__c chainStepA2 = ChainSteps.generateOne(chainA.Id, wiretapProcess.Id);
        
        // Event
        EventType__c eventTypeNotSubscribed = new EventType__c(Name = 'an-event-not-Subscribed');
        insert eventTypeNotSubscribed;

        // Config A1
        Id configurationIdA1 = (Id) [
            SELECT Id, ConfigurationId__c
            FROM ChainStep__c
            WHERE Id = :chainStepA1.Id LIMIT 1
        ].ConfigurationId__c;
    
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

        //arrange processes
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c publishProcess = Processes.generateOne(Publish.class);
        
        // Chain B - Problem : No Configuration
        ChainStep__c chainStepB1 = ChainSteps.generateOne(chainB.Id, publishProcess.Id);
        ChainStep__c chainStepB2 = ChainSteps.generateOne(chainB.Id, wiretapProcess.Id);

        Id configurationIdB1 = (Id) [
            SELECT Id, ConfigurationId__c
            FROM ChainStep__c
            WHERE Id = :chainStepB1.Id LIMIT 1
         ].ConfigurationId__c;
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

        //arrange processes
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c publishProcess = Processes.generateOne(Publish.class);
        
        // Chain B - Problem : No Configuration
        ChainStep__c chainStepB1 = ChainSteps.generateOne(chainB.Id, publishProcess.Id);
        ChainStep__c chainStepB2 = ChainSteps.generateOne(chainB.Id, wiretapProcess.Id);
        
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