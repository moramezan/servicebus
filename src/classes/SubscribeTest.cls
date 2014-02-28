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
        List<Map<string, object>> parametersList = EdaUtility.convert(result);
        
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = data;
        string actualData = system.json.serialize(parametersList[0]);
        System.assertEquals(expectedData, actualData);
    }

      static testMethod void callingGetHealthReturnsExpectedListContaingStausEqUnknown() {

        // Arrange :
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
 
        // Processes :: Subscribe process not defined
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;
        
        // Sequence A
        Step__c stepA1 =  new Step__c(Sequence__c = sequenceA.Id, Process__c = wireTapProcess.Id, Position__c  = 1);
        Step__c stepA2 =  new Step__c(Sequence__c = sequenceA.Id, Process__c = wireTapProcess.Id, Position__c = 2);

        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualUnknownCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            sequenceIdToDescription.put(SubscribeHealth.SequenceId, SubscribeHealth.Detail);
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
        
        String actualUnknown = sequenceIdToDescription.get(sequenceA.Id);
        String expectedUnknown = 'Cannot resolve Id of Subscribe process';
        System.assertEquals(expectedUnknown, actualUnknown);
    }

    
  
    static testMethod void callingGetHealthReturnsExpectedListContaningStatusEqOk() {


        // Arrange :
        Sequence__c sequencePublish = new Sequence__c(Name = 'Publish');
        insert sequencePublish;
        Sequence__c sequenceZ = new Sequence__c(Name = 'SequenceZ');
        insert sequenceZ;
        
        //generate processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c publishProcess = Processes.generateOne(Publish.class);
        
        // Sequence Z - OK : Event is published
        Step__c stepZ1 = Steps.generateOne(sequenceZ.Id, subscribeProcess.Id);
        Step__c stepZ2 = Steps.generateOne(sequenceZ.Id, wiretapProcess.Id);
        Step__c stepZ3 = Steps.generateOne(sequencePublish.Id, publishProcess.Id);
 
        // Event
        EventType__c  eventTypePublished  = new EventType__c(Name = 'an-event-that-IS-published');
        insert  eventTypePublished ;
        

        // Config Publish
        Id publishConfigurationIdZ3 = (Id) [SELECT Id, ConfigurationId__c
                                     FROM Step__c
                                     WHERE Id = :stepZ3.Id LIMIT 1].ConfigurationId__c;
        PublishConfiguration__c  publishConfigurationZ3 =  [SELECT Id, EventType__c
                                                              FROM PublishConfiguration__c
                                                              WHERE Id = :publishConfigurationIdZ3];
        publishConfigurationZ3.EventType__c =  eventTypePublished .Id;
        update publishConfigurationZ3;
        
        // Config Z1
        Id configurationIdZ1 = (Id) [SELECT Id, ConfigurationId__c
                                     FROM Step__c
                                     WHERE Id = :stepZ1.Id LIMIT 1].ConfigurationId__c;
        SubscribeConfiguration__c  subscribeConfigurationZ1 =  [SELECT Id, EventType__c
                                                              FROM SubscribeConfiguration__c
                                                              WHERE Id = :configurationIdZ1];
        subscribeConfigurationZ1.EventType__c =  eventTypePublished .Id;
        update subscribeConfigurationZ1;
        
  
        
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualOkCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            sequenceIdToDescription.put(SubscribeHealth.SequenceId, SubscribeHealth.Detail);
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
        
        //arrange sequence
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        
        // Sequence A - Warning : Ok but event Not published
        Step__c stepA1 = Steps.generateOne(sequenceA.Id, subscribeProcess.Id);
        Step__c stepA2 = Steps.generateOne(sequenceA.Id, wiretapProcess.Id);

        // Event
        EventType__c eventNotPublished = new EventType__c(Name = 'an-event-not-published');
        insert eventNotPublished;
       
        // Config A1
        Id configurationIdA1 = (Id) [SELECT Id, ConfigurationId__c
                                     FROM Step__c
                                     WHERE Id = :stepA1.Id LIMIT 1].ConfigurationId__c;
        SubscribeConfiguration__c  subscribeConfigurationA1 =  [SELECT Id, EventType__c
                                                              FROM SubscribeConfiguration__c
                                                              WHERE Id = :configurationIdA1];
        subscribeConfigurationA1.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationA1;
 
 
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualWarningCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            sequenceIdToDescription.put(SubscribeHealth.SequenceId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Warning') {
                actualWarningCount++;
            }
        }
        
        // Assert :
        Integer expectedWarningCount = 1;
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String actualDescription = sequenceIdToDescription.get(sequenceA.Id);
        String expectedDescription = 'No publisher is configured to publish';
        System.assert(actualDescription.contains(expectedDescription));
 
    }
    
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNotFirst() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : Subscribe Not first Step
        Step__c stepB1 = Steps.generateOne(sequenceB.Id, wiretapProcess.Id);
        Step__c stepB2 = Steps.generateOne(sequenceB.Id, subscribeProcess.Id);
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            sequenceIdToDescription.put(SubscribeHealth.SequenceId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualSequenceSubscribeNotLastStep = sequenceIdToDescription.get(sequenceB.Id);
        String expectedSequenceSubscribeNotLastStep = 'Subscribe process not  at front of sequence';
        System.assertEquals(expectedSequenceSubscribeNotLastStep, actualSequenceSubscribeNotLastStep);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorGtOne() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        
        //arrange sequence
        Sequence__c sequenceC = new Sequence__c(Name = 'SequenceC');
        insert sequenceC;
        
        // Sequence C - Problem : Subscribe Step Occurs more than once
        Step__c stepC1 = Steps.generateOne(sequenceC.Id, subscribeProcess.Id);
        Step__c stepC2 = Steps.generateOne(sequenceC.Id, subscribeProcess.Id);
            
        // Event
        EventType__c eventNotPublished = new EventType__c(Name = 'an-event-not-published');
        insert eventNotPublished;

        

        
        // Config C1
        Id configurationIdC1 = (Id) [SELECT Id, ConfigurationId__c
                                   FROM Step__c
                                   WHERE Id = :stepC1.Id LIMIT 1].ConfigurationId__c;
        SubscribeConfiguration__c  subscribeConfigurationC1 =  [SELECT Id, EventType__c
                                                              FROM SubscribeConfiguration__c
                                                              WHERE Id = :configurationIdC1];
        subscribeConfigurationC1.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationC1;

        // Config C2
        Id configurationIdC2 = (Id) [SELECT Id, ConfigurationId__c
                                   FROM Step__c
                                   WHERE Id = :stepC2.Id LIMIT 1].ConfigurationId__c;
        SubscribeConfiguration__c  subscribeConfigurationC2 =  [SELECT Id, EventType__c
                                                              FROM SubscribeConfiguration__c
                                                              WHERE Id = :configurationIdC2];
        subscribeConfigurationC2.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationC2;
        
        
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            sequenceIdToDescription.put(SubscribeHealth.SequenceId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = sequenceIdToDescription.get(sequenceC.Id);
        String expectedDescription = 'Subscribe appears more than once in sequence';
        System.assert(actualDescription.contains(expectedDescription));
    }


    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoConfig() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;

        // Sequence B - Problem : No Configuration
        Step__c stepB1 = Steps.generateOne(sequenceB.Id, subscribeProcess.Id);
        Step__c stepB2 = Steps.generateOne(sequenceB.Id, wiretapProcess.Id);

        Id configurationIdB1 = (Id) [SELECT Id, ConfigurationId__c
                                     FROM Step__c
                                     WHERE Id = :stepB1.Id LIMIT 1].ConfigurationId__c;
        Database.delete(configurationIdB1);
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            sequenceIdToDescription.put(SubscribeHealth.SequenceId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualSequenceSubscribeNotLastStep = sequenceIdToDescription.get(sequenceB.Id);
        String expectedSequenceSubscribeNotLastStep = 'Cannot resolve subscribe configuration';
        System.assertEquals(expectedSequenceSubscribeNotLastStep, actualSequenceSubscribeNotLastStep);
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfig() {
        //arrange processes
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : No Configuration
        Step__c stepB1 = Steps.generateOne(sequenceB.Id, subscribeProcess.Id);
        Step__c stepB2 = Steps.generateOne(sequenceB.Id, wiretapProcess.Id);

        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            sequenceIdToDescription.put(SubscribeHealth.SequenceId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = sequenceIdToDescription.get(sequenceB.Id);
        String expectedDescription = 'No event type defined on subscribe configuration';
        System.assert(actualDescription.contains(expectedDescription));
    }

}