@isTest private class SubscribeTest{
    
    static testMethod void canDetermineConfigurable() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        
        //act
        String actualConfiguration = subscribeProcess.Configurable__c;
        
        // Assert
        String expectedConfiguration = Schema.SobjectType.SubscribeConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
    
    static testMethod void testSubscribeProcessActsAsNoop() {
        //arrange
        String data = '{"herp":"derp"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        Subscribe process = new Subscribe();
        
        //act
        Process.PluginResult result = process.invoke(new Process.PluginRequest(parameters));
        
        //assert
        List<Map<string, object>> parametersList = Utility.convert(result);
        
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = data;
        string actualData = system.json.serialize(parametersList[0]);
        System.assertEquals(expectedData, actualData);
    }

      static testMethod void callingGetHealthReturnsExpectedListContaingStausEqUnknown() {

        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
 
        // Processes :: Subscribe process not defined
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;
        
        // Chain A
        ChainStep__c chainStepA1 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c  = 1);
        ChainStep__c chainStepA2 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c = 2);

        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualUnknownCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Unknown') {
                actualUnknownCount++;
            }
        }
        
        // Assert :
        Integer expectedCount = 1;
        Integer actualCount = SubscribeHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedUnknownCount = 1;
        System.assertEquals(expectedUnknownCount, actualUnknownCount);
        
        String actualUnknown = chainIdToDescription.get(chainA.Id);
        String expectedUnknown = 'Cannot resolve Id of Subscribe process';
        System.assertEquals(expectedUnknown, actualUnknown);
    }

    
  
    static testMethod void callingGetHealthReturnsExpectedListContaningStatusEqOk() {


        // Arrange :
        Chain__c chainPublish = new Chain__c(Name = 'Publish');
        insert chainPublish;
        Chain__c chainZ = new Chain__c(Name = 'ChainZ');
        insert chainZ;
        
        //generate processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c publishProcess = Processes.generateOne(Publish.class);
        
        // Chain Z - OK : Event is published
        ChainStep__c chainStepZ1 = ChainSteps.generateOne(chainZ.Id, subscribeProcess.Id);
        ChainStep__c chainStepZ2 = ChainSteps.generateOne(chainZ.Id, wiretapProcess.Id);
        ChainStep__c chainStepZ3 = ChainSteps.generateOne(chainPublish.Id, publishProcess.Id);
 
        // Event
        EventType__c  eventTypePublished  = new EventType__c(Name = 'an-event-that-IS-published');
        insert  eventTypePublished ;
        

        // Config Publish
        Id publishConfigurationIdZ3 = (Id) [SELECT Id, ConfigurationId__c
                                     FROM ChainStep__c
                                     WHERE Id = :chainStepZ3.Id LIMIT 1].ConfigurationId__c;
        PublishConfiguration__c  publishConfigurationZ3 =  [SELECT Id, EventType__c
                                                              FROM PublishConfiguration__c
                                                              WHERE Id = :publishConfigurationIdZ3];
        publishConfigurationZ3.EventType__c =  eventTypePublished .Id;
        update publishConfigurationZ3;
        
        // Config Z1
        Id configurationIdZ1 = (Id) [SELECT Id, ConfigurationId__c
                                     FROM ChainStep__c
                                     WHERE Id = :chainStepZ1.Id LIMIT 1].ConfigurationId__c;
        SubscribeConfiguration__c  subscribeConfigurationZ1 =  [SELECT Id, EventType__c
                                                              FROM SubscribeConfiguration__c
                                                              WHERE Id = :configurationIdZ1];
        subscribeConfigurationZ1.EventType__c =  eventTypePublished .Id;
        update subscribeConfigurationZ1;
        
  
        
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualOkCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Ok') {
                actualOkCount++;
            }
        }
        
        // Assert :
        Integer expectedCount = 1 + 1; // <Subscribe> + <Publish=1>
        Integer actualCount = SubscribeHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedOkCount = 1 + 1; // <Ok,Subscribe> + <Ok,Publish=1>
        System.assertEquals(expectedOkCount, actualOkCount);
    }
 


    static testMethod void callingGetHealthReturnsExpectedListContaningStatusEqWarning() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange chain
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
        
        // Chain A - Warning : Ok but event Not published
        ChainStep__c chainStepA1 = ChainSteps.generateOne(chainA.Id, subscribeProcess.Id);
        ChainStep__c chainStepA2 = ChainSteps.generateOne(chainA.Id, wiretapProcess.Id);

        // Event
        EventType__c eventNotPublished = new EventType__c(Name = 'an-event-not-published');
        insert eventNotPublished;
       
        // Config A1
        Id configurationIdA1 = (Id) [SELECT Id, ConfigurationId__c
                                     FROM ChainStep__c
                                     WHERE Id = :chainStepA1.Id LIMIT 1].ConfigurationId__c;
        SubscribeConfiguration__c  subscribeConfigurationA1 =  [SELECT Id, EventType__c
                                                              FROM SubscribeConfiguration__c
                                                              WHERE Id = :configurationIdA1];
        subscribeConfigurationA1.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationA1;
 
 
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualWarningCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Warning') {
                actualWarningCount++;
            }
        }
        
        // Assert :
        Integer expectedWarningCount = 1;
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String actualDescription = chainIdToDescription.get(chainA.Id);
        String expectedDescription = 'No publisher is configured to publish';
        System.assert(actualDescription.contains(expectedDescription));
 
    }
    
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNotFirst() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange chain
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;
        
        // Chain B - Problem : Subscribe Not first Step
        ChainStep__c chainStepB1 = ChainSteps.generateOne(chainB.Id, wiretapProcess.Id);
        ChainStep__c chainStepB2 = ChainSteps.generateOne(chainB.Id, subscribeProcess.Id);
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualChainSubscribeNotLastStep = chainIdToDescription.get(chainB.Id);
        String expectedChainSubscribeNotLastStep = 'Subscribe process not  at front of chain';
        System.assertEquals(expectedChainSubscribeNotLastStep, actualChainSubscribeNotLastStep);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorGtOne() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        
        //arrange chain
        Chain__c chainC = new Chain__c(Name = 'ChainC');
        insert chainC;
        
        // Chain C - Problem : Subscribe Step Occurs more than once
        ChainStep__c chainStepC1 = ChainSteps.generateOne(chainC.Id, subscribeProcess.Id);
        ChainStep__c chainStepC2 = ChainSteps.generateOne(chainC.Id, subscribeProcess.Id);
            
        // Event
        EventType__c eventNotPublished = new EventType__c(Name = 'an-event-not-published');
        insert eventNotPublished;

        

        
        // Config C1
        Id configurationIdC1 = (Id) [SELECT Id, ConfigurationId__c
                                   FROM ChainStep__c
                                   WHERE Id = :chainStepC1.Id LIMIT 1].ConfigurationId__c;
        SubscribeConfiguration__c  subscribeConfigurationC1 =  [SELECT Id, EventType__c
                                                              FROM SubscribeConfiguration__c
                                                              WHERE Id = :configurationIdC1];
        subscribeConfigurationC1.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationC1;

        // Config C2
        Id configurationIdC2 = (Id) [SELECT Id, ConfigurationId__c
                                   FROM ChainStep__c
                                   WHERE Id = :chainStepC2.Id LIMIT 1].ConfigurationId__c;
        SubscribeConfiguration__c  subscribeConfigurationC2 =  [SELECT Id, EventType__c
                                                              FROM SubscribeConfiguration__c
                                                              WHERE Id = :configurationIdC2];
        subscribeConfigurationC2.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationC2;
        
        
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = chainIdToDescription.get(chainC.Id);
        String expectedDescription = 'Subscribe appears more than once in chain';
        System.assert(actualDescription.contains(expectedDescription));
    }


    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoConfig() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange chain
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;

        // Chain B - Problem : No Configuration
        ChainStep__c chainStepB1 = ChainSteps.generateOne(chainB.Id, subscribeProcess.Id);
        ChainStep__c chainStepB2 = ChainSteps.generateOne(chainB.Id, wiretapProcess.Id);

        Id configurationIdB1 = (Id) [SELECT Id, ConfigurationId__c
                                     FROM ChainStep__c
                                     WHERE Id = :chainStepB1.Id LIMIT 1].ConfigurationId__c;
        Database.delete(configurationIdB1);
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualChainSubscribeNotLastStep = chainIdToDescription.get(chainB.Id);
        String expectedChainSubscribeNotLastStep = 'Cannot resolve subscribe configuration';
        System.assertEquals(expectedChainSubscribeNotLastStep, actualChainSubscribeNotLastStep);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfig() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange chain
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;
        
        // Chain B - Problem : No Configuration
        ChainStep__c chainStepB1 = ChainSteps.generateOne(chainB.Id, subscribeProcess.Id);
        ChainStep__c chainStepB2 = ChainSteps.generateOne(chainB.Id, wiretapProcess.Id);

        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = chainIdToDescription.get(chainB.Id);
        String expectedDescription = 'No event type defined on subscribe configuration';
        System.assert(actualDescription.contains(expectedDescription));
    }

}