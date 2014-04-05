@isTest private class PublishTest {

    static testMethod void canDetermineConfigObject() {
        //arrange processes
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        
        //act
        String actualConfiguration = publishProcess.ConfigObject__c;
        
        //assert
        String expectedConfiguration = Schema.SObjectType.PublishConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
    
    static testMethod void testSubsequenceDropped() {
        //arrange events
        EventType__c eventType = new EventType__c(Name = 'ready');
        insert eventType;
        
        //arrange processes
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        
        //arrange publish config
        PublishConfiguration__c pubConfig = new PublishConfiguration__c(
            EventType__c = eventType.Id
        );
        insert pubConfig;
        
        //arrange sequence
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        
        Step__c subscribeStep = StepSet.generateOne(target.Id, subscribeProcess.Id);
        
        //arrange subscribe config
        Database.update(new SubscribeConfiguration__c(
            Id = subscribeStep.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        Map<String,Object> parameters = new Map<String,Object>{
            'eda_ConfigObjectId' => pubConfig.Id,
            'eda_SubsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Publish plugin = new Publish();
        List<Map<String,Object>> parametersList = EdaUtility.convert(plugin.invoke(new Process.PluginRequest(parameters)));
        
        //should return one for sub, one for passthru
        Integer expectedSize = 2;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        //first one is for subscriber
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[0].get('eda_SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
        
        //second one is original/passthru
        expectedIds = new List<Id>{'000000000000000AAA'};
        actualIds = (List<Object>)parametersList[1].get('eda_SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testMethod void testUnconfiguredPublishProcessThrowsException() {
        //arrange processes
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepSet.generateOne(sequence.Id, publishProcess.Id);
        
        PublishConfiguration__c config = new PublishConfiguration__c();
        insert config;
        
        Publish plugin = new Publish();
        Map<String,Object> parameters = new Map<String,Object>{'eda_SequenceName' => 'TestSequence', 'eda_Position' => 1, 'eda_ConfigObjectId' => config.Id};
        Process.PluginRequest request = new Process.PluginRequest(parameters);
        
        //act
        Boolean thrown = false;
        try {plugin.invoke(request);}
        catch (Publish.PublishException e) {thrown = true;}
        
        //assert
        System.assert(thrown);
    }
    
    static testMethod void testNoSubscribersStillReturnsOneMessage() {
        //arrange processes
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepSet.generateOne(sequence.Id, publishProcess.Id);
        Database.update(new PublishConfiguration__c(
            Id = step.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        String data = '{"eda_SequenceName":"TestSequence","eda_Position":1,"eda_ConfigObjectId":"' + step.ConfigurationId__c + '"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        Publish plugin = new Publish();
        
        //act
        Process.PluginResult results = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> parametersList = EdaUtility.convert(results);
        
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
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        
        //arrange publish sequences and steps
        Sequence__c publisher = new Sequence__c(Name = 'Publisher');
        insert publisher;
        
        Step__c publisherStep = StepSet.generateOne(publisher.Id, publishProcess.Id);
        Database.update(new PublishConfiguration__c(
            Id = publisherStep.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        //arrange subscribe sequences and steps
        Sequence__c subscriber1 = new Sequence__c(Name = 'Subscriber1');
        insert subscriber1;
        
        Step__c subscriber1step = StepSet.generateOne(subscriber1.Id, subscribeProcess.Id);
        Database.update(new SubscribeConfiguration__c(
            Id = subscriber1step.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        Sequence__c subscriber2 = new Sequence__c(Name = 'Subscriber2');
        insert subscriber2;
        
        Step__c subscriber2step = StepSet.generateOne(subscriber2.Id, subscribeProcess.Id);
        Database.update(new SubscribeConfiguration__c(
            Id = subscriber2step.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        //arrange
        Map<String,Object> parameters = new Map<String,Object>{'eda_SequenceName' => 'Publisher', 'eda_Position' => 1, 'eda_ConfigObjectId' => publisherStep.ConfigurationId__c};
        
        //act
        Publish plugin = new Publish();
        Process.PluginResult results = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> parametersList = EdaUtility.convert(results);
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContaingStausEqUnknown() {
        // Arrange :
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
 
        // Process :: Publish process not defined
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        
        // Sequence A
        Step__c stepA1 = StepSet.generateOne(sequenceA.Id, wiretapProcess.Id);
        Step__c stepA2 = StepSet.generateOne(sequenceA.Id, wiretapProcess.Id);

        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth();
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualUnknownCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            sequenceIdToDescription.put(PublishHealth.SequenceId, PublishHealth.Detail);
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
        
        String actualUnknown = sequenceIdToDescription.get(sequenceA.Id);
        String expectedUnknown = 'Cannot resolve Id of Publish process';
        System.assertEquals(expectedUnknown, actualUnknown);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContaningStatusEqOk() {
        // Arrange :
        Sequence__c sequenceSubscribe = new Sequence__c(Name = 'Subscribe');
        insert sequenceSubscribe;
        Sequence__c sequenceZ = new Sequence__c(Name = 'SequenceZ');
        insert sequenceZ;

        //arrange processes
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);

        // Sequence Z - OK : Event is Subscribed
        Step__c stepZ1 = StepSet.generateOne(sequenceZ.Id, publishProcess.Id);
        Step__c stepZ2 = StepSet.generateOne(sequenceZ.Id, wiretapProcess.Id);
        Step__c stepZ3 = StepSet.generateOne(sequenceSubscribe.Id, subscribeProcess.Id);

        // Event
        EventType__c eventTypeSubscribed = new EventType__c(Name = 'an-event-that-IS-Subscribed');
        insert eventTypeSubscribed;

        // Config Subscribe
        Id SubscribeConfigurationIdZ3 = ((Step__c)SalesforceObject.getById(stepZ3.Id)).ConfigurationId__c;
            
        SubscribeConfiguration__c SubscribeConfigurationZ3 = (SubscribeConfiguration__c)SalesforceObject.getById(SubscribeConfigurationIdZ3);
        
        SubscribeConfigurationZ3.EventType__c = eventTypeSubscribed.Id;
        update SubscribeConfigurationZ3;
        
        // Config Z1
        Id configurationIdZ1 = ((Step__c)SalesforceObject.getById(stepZ1.Id)).ConfigurationId__c;
        
        PublishConfiguration__c PublishConfigurationZ1 = (PublishConfiguration__c)SalesforceObject.getById(configurationIdZ1);
        
        PublishConfigurationZ1.EventType__c = eventTypeSubscribed.Id;
        update PublishConfigurationZ1;

        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth();
        
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualOkCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            sequenceIdToDescription.put(PublishHealth.SequenceId, PublishHealth.Detail);
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
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;

        //arrange proceses
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        
        // Sequence A - Warning : Ok but event Not Subscribed
        Step__c stepA1 = StepSet.generateOne(sequenceA.Id, publishProcess.Id);
        Step__c stepA2 = StepSet.generateOne(sequenceA.Id, wiretapProcess.Id);
        
        // Event
        EventType__c eventTypeNotSubscribed = new EventType__c(Name = 'an-event-not-Subscribed');
        insert eventTypeNotSubscribed;

        // Config A1
        Id configurationIdA1 = ((Step__c)SalesforceObject.getById(stepA1.Id)).ConfigurationId__c;
    
        PublishConfiguration__c PublishConfigurationA1 = (PublishConfiguration__c)SalesforceObject.getById(configurationIdA1);

        PublishConfigurationA1.EventType__c = eventTypeNotSubscribed.Id;
        update PublishConfigurationA1;

        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth();
        
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualWarningCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            sequenceIdToDescription.put(PublishHealth.SequenceId, PublishHealth.Detail);
            if (PublishHealth.Status == 'Warning') {
                actualWarningCount++;
            }
        }
        
        // Assert :
        Integer expectedWarningCount = 1;
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String actualDescription = sequenceIdToDescription.get(sequenceA.Id);
        String expectedDescription = 'No Subscriber is configured to subscribe';
        System.assert(actualDescription.contains(expectedDescription));
    }

    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoConfig() {
        // Arrange :
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;

        //arrange processes
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        
        // Sequence B - Problem : No Configuration
        Step__c stepB1 = StepSet.generateOne(sequenceB.Id, publishProcess.Id);
        Step__c stepB2 = StepSet.generateOne(sequenceB.Id, wiretapProcess.Id);

        Id configurationIdB1 = ((Step__c)SalesforceObject.getById(stepB1.Id)).ConfigurationId__c;
        Database.delete(configurationIdB1);
        
        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth();
        
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            sequenceIdToDescription.put(PublishHealth.SequenceId, PublishHealth.Detail);
            if (PublishHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = sequenceIdToDescription.get(sequenceB.Id);
        String expectedDescription = 'Cannot resolve Publish configuration';
        System.assert(actualDescription.contains(expectedDescription));
    }
         
 
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfig() {
        // Arrange :
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;

        //arrange processes
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        
        // Sequence B - Problem : No Configuration
        Step__c stepB1 = StepSet.generateOne(sequenceB.Id, publishProcess.Id);
        Step__c stepB2 = StepSet.generateOne(sequenceB.Id, wiretapProcess.Id);
        
        // Act :
        List<HealthController.Health> PublishHealths = Publish.getHealth();
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health PublishHealth : PublishHealths ) {
            sequenceIdToDescription.put(PublishHealth.SequenceId, PublishHealth.Detail);
            if (PublishHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = sequenceIdToDescription.get(sequenceB.Id);
        String expectedDescription = 'No event type defined on Publish configuration';
        System.assert(actualDescription.contains(expectedDescription));
    }
}