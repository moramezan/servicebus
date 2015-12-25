@IsTest class SequenceEditExtensionTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static Id setupSequence() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        
        //arrange steps
        model.appendStep(WiretapService.class);
        model.appendStep(TerminateService.class);
        
        return sequence.Id;
    }
    
    static testmethod void testGetSteps() {
        //arrange sequence, controller and extension
        Id sequenceId = setupSequence();
        ApexPages.StandardController controller = new ApexPages.StandardController(new Sequence__c(Id = sequenceId, Name = 'SequenceEditExtensionTest'));
        SequenceEditExtension extension = new SequenceEditExtension(controller);
        
        //act
        String data = extension.getSteps();
        
        //assemble
        List<Object> steps = (List<Object>)Json.deserializeUntyped(data);
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = steps.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testFetchSteps() {
        //arrange
        Id sequenceId = setupSequence();
        
        //act
        List<Map<String,Object>> sequenceSteps = SequenceEditExtension.fetchSteps(sequenceId);
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = sequenceSteps.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testAppendStep() {
        //arrange sequence
        Id sequenceId = setupSequence();
        
        //act
        SequenceEditExtension.appendStep(sequenceId, [SELECT Id FROM ApexClass WHERE Name = 'PublishService' AND NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c].Id);
        
        //assemble
        Step__c step = Step__c.getValues('1#Test#3');
        
        //assert
        String expectedClassName = PublishService.class.getName();
        String actualClassName = step.ApexTypeName__c;
        System.assertEquals(expectedClassName, actualClassName);
    }
    
    static testmethod void testMoveStepBefore() {
        //arrange sequence
        Id sequenceId = setupSequence();
        
        //act
        SequenceEditExtension.moveStepBefore('1#Test#2', '1#Test#1');
        
        //assemble
        List<Map<String,Object>> steps = SequenceModel.fromId(sequenceId).stepDtos();
        Map<String,Object> terminateStep = steps[0];
        Map<String,Object> wiretapStep = steps[1];
        
        //assert
        String terminateExpectedApexTypeName = TerminateService.class.getName();
        String terminateActualApexTypeName = (String)terminateStep.get('ApexTypeName');
        System.assertEquals(terminateExpectedApexTypeName, terminateActualApexTypeName);
        
        String wiretapExpectedApexTypeName = WiretapService.class.getName();
        String wiretapActualApexTypeName = (String)wiretapStep.get('ApexTypeName');
        System.assertEquals(wiretapExpectedApexTypeName, wiretapActualApexTypeName);
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange sequence
        Id sequenceId = setupSequence();
        
        //act
        SequenceEditExtension.moveStepAfter('1#Test#1', '1#Test#2');
        
        //assemble
        List<Map<String,Object>> steps = SequenceModel.fromId(sequenceId).stepDtos();
        Map<String,Object> terminateStep = steps[0];
        Map<String,Object> wiretapStep = steps[1];
        
        //assert
        String terminateExpectedApexTypeName = TerminateService.class.getName();
        String terminateActualApexTypeName = (String)terminateStep.get('ApexTypeName');
        System.assertEquals(terminateExpectedApexTypeName, terminateActualApexTypeName);
        
        String wiretapExpectedApexTypeName = WiretapService.class.getName();
        String wiretapActualApexTypeName = (String)wiretapStep.get('ApexTypeName');
        System.assertEquals(wiretapExpectedApexTypeName, wiretapActualApexTypeName);
    }
    
    static testmethod void testDestroyStep() {
        //arrange
        Id sequenceId = setupSequence();
        
        //act
        SequenceEditExtension.destroyStep(sequenceId, '1#Test#1');
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = SequenceModel.fromId(sequenceId).stepDtos().size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    /**
     * Health check stuff
     */
    static testmethod void callingGetHeathReturnsExpectedList() {
        // #11 : Trivial error / health checker
        // * Sequence with no Terminate (error)
        // * Sequence with more than one Terminate (error)
        // * Terminate that's not at the end (error)
        
        // Arrange :
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        Sequence__c sequenceC = new Sequence__c(Name = 'SequenceC');
        insert sequenceC;
        Sequence__c sequenceD = new Sequence__c(Name = 'SequenceD');
        insert sequenceD;
        
        // Sequence A - Ok
        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(WiretapService.class);
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(TerminateService.class);
        
        // Sequence B - Problem : Terminate Not last Step
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(TerminateService.class);
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(WiretapService.class);
 
        // Sequence C - Problem : More than One Terminate
        Step__c stepC1 = SequenceModel.fromName(sequenceC.Name).appendStep(TerminateService.class);
        Step__c stepC2 = SequenceModel.fromName(sequenceC.Name).appendStep(TerminateService.class);
        
        // Sequence D - Problem : Zero Terminate
        Step__c stepD1 = SequenceModel.fromName(sequenceD.Name).appendStep(WiretapService.class);
        Step__c stepD2 = SequenceModel.fromName(sequenceD.Name).appendStep(WiretapService.class);

        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceA);
        SequenceEditExtension controller = new SequenceEditExtension(standardController);
        controller.findTerminateProblems();
        
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assemble :
        Integer expectedCount = 3;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
        
        String actualSequenceTerminateNotLastStep = sequenceB.Id;
        String expectedSequenceTerminateNotLastStep = 'Terminate not present at end of sequence';
        System.assert(messages[0].getSummary().contains(actualSequenceTerminateNotLastStep));
        System.assert(messages[0].getSummary().contains(expectedSequenceTerminateNotLastStep));
        
        String actualSequenceMoreThanOneTerminate = sequenceC.Id;
        String expectedSequenceMoreThanOneTerminate = 'More than one Terminate found in sequence';
        System.assert(messages[1].getSummary().contains(actualSequenceMoreThanOneTerminate));
        System.assert(messages[1].getSummary().contains(expectedSequenceMoreThanOneTerminate));
        
        String actualSequenceZeroTerminates = sequenceD.Id;
        String expectedSequenceZeroTerminates =  'No Terminate found in sequence';
        System.assert(messages[2].getSummary().contains(actualSequenceZeroTerminates));
        System.assert(messages[2].getSummary().contains(expectedSequenceZeroTerminates));
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContaningStatusEqWarningPublish() {
        // Arrange :
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        
        // Sequence A - Warning : Ok but event Not Subscribed
        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(PublishService.class);
        new StepModel(stepA1).upsertConfig();
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(WiretapService.class);
        
        // Config A1
        Id configIdA1 = ((Step__c)ApexDomain.getById(stepA1.Id)).ConfigId__c;
        
        PublishStepConfig__c PublishConfigA1 = (PublishStepConfig__c)ApexDomain.getById(configIdA1);
        
        PublishConfigA1.Topic__c = 'an-event-not-published';
        update PublishConfigA1;
        
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceA);
        SequenceEditExtension controller = new SequenceEditExtension(standardController);
        controller.findPublishProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedWarningCount = 1;
        Integer actualWarningCount = messages.size();
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String expectedDescription = 'There are no subscribers listening to the event';
        String actualDescription = messages[0].getSummary();
        System.assert(actualDescription.contains(expectedDescription));
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfigPublish() {
        // Arrange :
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : No Config
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(PublishService.class);
        new StepModel(stepB1).upsertConfig();
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(WiretapService.class);
        
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceB);
        SequenceEditExtension controller = new SequenceEditExtension(standardController);
        controller.findPublishProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);
        
        String expectedDescription = 'No topic has been configured';
        String actualDescription = messages[0].getSummary();
        System.assert(actualDescription.contains(expectedDescription), messages[0]);
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContaningStatusEqWarningSubscribe() {
        //arrange sequence
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        
        // Sequence A - Warning : Ok but event Not published
        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(SubscribeService.class);
        new StepModel(stepA1).upsertConfig();
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(WiretapService.class);

        // Config A1
        Id configIdA1 = ((Step__c)ApexDomain.getById(stepA1.Id)).ConfigId__c;
        SubscribeStepConfig__c subscribeConfigA1 = (SubscribeStepConfig__c)ApexDomain.getById(configIdA1);
        subscribeConfigA1.Topic__c = 'an-event-not-published';
        update subscribeConfigA1;
 
 
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceA);
        SequenceEditExtension controller = new SequenceEditExtension(standardController);
        controller.findSubscribeProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedWarningCount = 1;
        Integer actualWarningCount = messages.size();
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String actualDescription = sequenceA.Id;
        String expectedDescription = 'No publisher is configured to publish event';
        System.assert(messages[0].getSummary().contains(actualDescription));
        System.assert(messages[0].getSummary().contains(expectedDescription));
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNotFirst() {
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : Subscribe Not first Step
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(WiretapService.class);
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(SubscribeService.class);
        new StepModel(stepB2).upsertConfig();
        
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceB);
        SequenceEditExtension controller = new SequenceEditExtension(standardController);
        controller.findSubscribeProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualSequenceSubscribeNotLastStep = sequenceB.Id;
        String expectedSequenceSubscribeNotLastStep = 'Subscribe not first step of sequence';
        System.assert(messages[0].getSummary().contains(expectedSequenceSubscribeNotLastStep));
        System.assert(messages[0].getSummary().contains(actualSequenceSubscribeNotLastStep));
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorGtOne() {
        //arrange sequence
        Sequence__c sequenceC = new Sequence__c(Name = 'SequenceC');
        insert sequenceC;
        
        // Sequence C - Problem : Subscribe Step Occurs more than once
        Step__c stepC1 = SequenceModel.fromName(sequenceC.Name).appendStep(SubscribeService.class);
        new StepModel(stepC1).upsertConfig();
        Step__c stepC2 = SequenceModel.fromName(sequenceC.Name).appendStep(SubscribeService.class);
        new StepModel(stepC2).upsertConfig();
            
        // Config C1
        Id configIdC1 = ((Step__c)ApexDomain.getById(stepC1.Id)).ConfigId__c;
        SubscribeStepConfig__c subscribeConfigC1 = (SubscribeStepConfig__c)ApexDomain.getById(configIdC1);
        subscribeConfigC1.Topic__c = 'an-event-not-published';
        update subscribeConfigC1;

        // Config C2
        Id configIdC2 = ((Step__c)ApexDomain.getById(stepC2.Id)).ConfigId__c;
        SubscribeStepConfig__c subscribeConfigC2 = (SubscribeStepConfig__c)ApexDomain.getById(configIdC2);
        subscribeConfigC2.Topic__c = 'an-event-not-published';
        update subscribeConfigC2;
        
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceC);
        SequenceEditExtension controller = new SequenceEditExtension(standardController);
        controller.findSubscribeProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = sequenceC.Id;
        String expectedDescription = 'Subscribe appears more than once in sequence';
        System.assert(messages[0].getSummary().contains(expectedDescription));
        System.assert(messages[0].getSummary().contains(actualDescription));
    }

    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfigSubscribe() {
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : No Config
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(SubscribeService.class);
        new StepModel(stepB1).upsertConfig();
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(WiretapService.class);

        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceB);
        SequenceEditExtension controller = new SequenceEditExtension(standardController);
        controller.findSubscribeProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);
        
        String actualDescription = sequenceB.Id;
        String expectedDescription = 'No topic defined on Subscribe Config';
        System.assert(messages[0].getSummary().contains(expectedDescription));
        System.assert(messages[0].getSummary().contains(actualDescription));
    }
    
    static testmethod void testDoRedirect() {
        //arrange
        Id sequenceId = Database.insert(new Sequence__c(Name = 'Test')).getId();
        ApexPages.StandardController controller = new ApexPages.StandardController(new Sequence__c(Id = sequenceId));
        SequenceEditExtension extension = new SequenceEditExtension(controller);
        
        //act
        PageReference redirect = extension.doRedirect();
        
        //assert
        System.assertNotEquals(null, redirect, 'Wrong redirect.');
        
        //act (pretend to configure)
        Application__c application = Application__c.getOrgDefaults();
        application.RunAsAccessToken__c = '00D000000000000AAA';
        application.OrgConfigured__c = UserInfo.getOrganizationId().substring(3, 15);
        upsert application;
        
        //act (pretend to discover)
        ApexClassSetModel.saveCache(ApexClassSetModel.fromNamespace(Application__c.getOrgDefaults().Prefix__c).discoverSummaries());
        
        //act
        redirect = extension.doRedirect();
        
        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
    }
}