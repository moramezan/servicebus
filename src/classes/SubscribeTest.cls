@isTest private class SubscribeTest{
    
    static testMethod void canDetermineConfigObject() {
        //arrange processes
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        
        //act
        String actualConfiguration = subscribeProcess.ConfigObject__c;
        
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
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessSet.generateOne(Publish.class);
        
        // Sequence Z - OK : Event is published
        Step__c stepZ1 = StepSet.generateOne(sequenceZ.Id, subscribeProcess.Id);
        Step__c stepZ2 = StepSet.generateOne(sequenceZ.Id, wiretapProcess.Id);
        Step__c stepZ3 = StepSet.generateOne(sequencePublish.Id, publishProcess.Id);
 
        // Event
        EventType__c  eventTypePublished  = new EventType__c(Name = 'an-event-that-IS-published');
        insert  eventTypePublished ;
        

        // Config Publish
        Id publishConfigurationIdZ3 = ((Step__c)SalesforceObject.getById(stepZ3.Id)).ConfigurationId__c;
        PublishConfiguration__c publishConfigurationZ3 = (PublishConfiguration__c)SalesforceObject.getById(publishConfigurationIdZ3);
        publishConfigurationZ3.EventType__c = eventTypePublished.Id;
        update publishConfigurationZ3;
        
        // Config Z1
        Id configurationIdZ1 = ((Step__c)SalesforceObject.getById(stepZ1.Id)).ConfigurationId__c;
        SubscribeConfiguration__c subscribeConfigurationZ1 = (SubscribeConfiguration__c)SalesforceObject.getById(configurationIdZ1);
        subscribeConfigurationZ1.EventType__c = eventTypePublished.Id;
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
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        
        // Sequence A - Warning : Ok but event Not published
        Step__c stepA1 = StepSet.generateOne(sequenceA.Id, subscribeProcess.Id);
        Step__c stepA2 = StepSet.generateOne(sequenceA.Id, wiretapProcess.Id);

        // Event
        EventType__c eventNotPublished = new EventType__c(Name = 'an-event-not-published');
        insert eventNotPublished;
       
        // Config A1
        Id configurationIdA1 = ((Step__c)SalesforceObject.getById(stepA1.Id)).ConfigurationId__c;
        SubscribeConfiguration__c subscribeConfigurationA1 = (SubscribeConfiguration__c)SalesforceObject.getById(configurationIdA1);
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
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : Subscribe Not first Step
        Step__c stepB1 = StepSet.generateOne(sequenceB.Id, wiretapProcess.Id);
        Step__c stepB2 = StepSet.generateOne(sequenceB.Id, subscribeProcess.Id);
        
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
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        
        //arrange sequence
        Sequence__c sequenceC = new Sequence__c(Name = 'SequenceC');
        insert sequenceC;
        
        // Sequence C - Problem : Subscribe Step Occurs more than once
        Step__c stepC1 = StepSet.generateOne(sequenceC.Id, subscribeProcess.Id);
        Step__c stepC2 = StepSet.generateOne(sequenceC.Id, subscribeProcess.Id);
            
        // Event
        EventType__c eventNotPublished = new EventType__c(Name = 'an-event-not-published');
        insert eventNotPublished;

        

        
        // Config C1
        Id configurationIdC1 = ((Step__c)SalesforceObject.getById(stepC1.Id)).ConfigurationId__c;
        SubscribeConfiguration__c subscribeConfigurationC1 = (SubscribeConfiguration__c)SalesforceObject.getById(configurationIdC1);
        subscribeConfigurationC1.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationC1;

        // Config C2
        Id configurationIdC2 = ((Step__c)SalesforceObject.getById(stepC2.Id)).ConfigurationId__c;
        SubscribeConfiguration__c subscribeConfigurationC2 = (SubscribeConfiguration__c)SalesforceObject.getById(configurationIdC2);
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
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;

        // Sequence B - Problem : No Configuration
        Step__c stepB1 = StepSet.generateOne(sequenceB.Id, subscribeProcess.Id);
        Step__c stepB2 = StepSet.generateOne(sequenceB.Id, wiretapProcess.Id);

        Id configurationIdB1 = ((Step__c)SalesforceObject.getById(stepB1.Id)).ConfigurationId__c;
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
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : No Configuration
        Step__c stepB1 = StepSet.generateOne(sequenceB.Id, subscribeProcess.Id);
        Step__c stepB2 = StepSet.generateOne(sequenceB.Id, wiretapProcess.Id);

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