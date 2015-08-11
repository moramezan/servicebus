@IsTest public class SequenceBuilderExtensionTest {
    
    static private Id setupSequence() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        
        //arrange steps
        model.appendStep(Wiretap.class);
        model.appendStep(Terminate.class);
        
        return sequence.Id;
    }
    
    static testmethod void testGetProcesses() {
        //arrange sequence, controller and extension
        Id sequenceId = setupSequence();
        ApexPages.StandardController controller = new ApexPages.StandardController(new Sequence__c(Id = sequenceId, Name = 'SequenceBuilderExtensionTest'));
        SequenceBuilderExtension extension = new SequenceBuilderExtension(controller);
        
        //act
        String data = extension.getProcesses();
        
        //assemble
        List<Object> processes = (List<Object>)Json.deserializeUntyped(data);
        
        //assert
        Integer expectedCount = 5; //about 9
        Integer actualCount = processes.size();
        System.assert(actualCount > expectedCount, 'Wrong process count.');
    }
    
    static testmethod void testGetSteps() {
        //arrange sequence, controller and extension
        Id sequenceId = setupSequence();
        ApexPages.StandardController controller = new ApexPages.StandardController(new Sequence__c(Id = sequenceId, Name = 'SequenceBuilderExtensionTest'));
        SequenceBuilderExtension extension = new SequenceBuilderExtension(controller);
        
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
        List<Map<String,Object>> sequenceSteps = SequenceBuilderExtension.fetchSteps(sequenceId);
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = sequenceSteps.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testAppendStep() {
        //arrange sequence
        Id sequenceId = setupSequence();
        
        //act
        SequenceBuilderExtension.appendStep(sequenceId, [SELECT Id FROM ApexClass WHERE Name = 'Publish'].Id);
        
        //assemble
        Step__c step = [SELECT ApexClassName__c FROM Step__c WHERE Name = 'Test#3'];
        
        //assert
        String expectedClassName = Publish.class.getName();
        String actualClassName = step.ApexClassName__c;
        System.assertEquals(expectedClassName, actualClassName);
    }
    
    static testmethod void testMoveStepBefore() {
        //arrange sequence
        Id sequenceId = setupSequence();
        
        //act
        SequenceBuilderExtension.moveStepBefore('Test#2', 'Test#1');
        
        //assemble
        List<Step__c> steps = SequenceModel.fromId(sequenceId).stepSetModel().getRecords();
        Step__c terminateStep = steps[0];
        Step__c wiretapStep = steps[1];
        
        //assemble
        terminateStep = [SELECT Id, ApexClassName__c FROM Step__c WHERE Id = :terminateStep.Id];
        wiretapStep = [SELECT Id, ApexClassName__c FROM Step__c WHERE Id = :wiretapStep.Id];
        
        //assert
        String terminateExpectedClassName = Terminate.class.getName();
        String terminateActualClassName = terminateStep.ApexClassName__c;
        System.assertEquals(terminateExpectedClassName, terminateActualClassName);
        
        String wiretapExpectedClassName = Wiretap.class.getName();
        String wiretapActualClassName = wiretapStep.ApexClassName__c;
        System.assertEquals(wiretapExpectedClassName, wiretapActualClassName);
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange sequence
        Id sequenceId = setupSequence();
        
        //act
        SequenceBuilderExtension.moveStepAfter('Test#1', 'Test#2');
        
        //assemble
        List<Step__c> steps = SequenceModel.fromId(sequenceId).stepSetModel().getRecords();
        Step__c terminateStep = steps[0];
        Step__c wiretapStep = steps[1];
        
        //assemble
        terminateStep = [SELECT Id, ApexClassName__c FROM Step__c WHERE Id = :terminateStep.Id];
        wiretapStep = [SELECT Id, ApexClassName__c FROM Step__c WHERE Id = :wiretapStep.Id];
        
        //assert
        String terminateExpectedClassName = Terminate.class.getName();
        String terminateActualClassName = terminateStep.ApexClassName__c;
        System.assertEquals(terminateExpectedClassName, terminateActualClassName);
        
        String wiretapExpectedClassName = Wiretap.class.getName();
        String wiretapActualClassName = wiretapStep.ApexClassName__c;
        System.assertEquals(wiretapExpectedClassName, wiretapActualClassName);
    }
    
    static testmethod void testDestroyStep() {
        //arrange
        Id sequenceId = setupSequence();
        
        //act
        SequenceBuilderExtension.destroyStep(sequenceId, 'Test#1');
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = SequenceModel.fromId(sequenceId).stepSetModel().getRecords().size();
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
        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(Terminate.class);
        
        // Sequence B - Problem : Terminate Not last Step
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(Terminate.class);
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(Wiretap.class);
 
        // Sequence C - Problem : More than One Terminate
        Step__c stepC1 = SequenceModel.fromName(sequenceC.Name).appendStep(Terminate.class);
        Step__c stepC2 = SequenceModel.fromName(sequenceC.Name).appendStep(Terminate.class);
        
        // Sequence D - Problem : Zero Terminate
        Step__c stepD1 = SequenceModel.fromName(sequenceD.Name).appendStep(Wiretap.class);
        Step__c stepD2 = SequenceModel.fromName(sequenceD.Name).appendStep(Wiretap.class);

        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceA);
        SequenceBuilderExtension controller = new SequenceBuilderExtension(standardController);
        controller.findTerminateProblems();
        
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assemble :
        Integer expectedCount = 3;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
        
        String actualSequenceTerminateNotLastStep = sequenceB.Id;
        String expectedSequenceTerminateNotLastStep = 'Terminate process not present at end of sequence';
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
        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Publish.class);
        new StepModel(stepA1).upsertConfig();
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        
        // Event
        EventType__c eventTypeNotSubscribed = new EventType__c(
            Name = 'an-event-not-Subscribed'
        );
        insert eventTypeNotSubscribed;
        
        // Config A1
        Id configIdA1 = ((Step__c)ApexDomain.getById(stepA1.Id)).ConfigId__c;
        
        PublishConfig__c PublishConfigA1 = (PublishConfig__c)ApexDomain.getById(configIdA1);
        
        PublishConfigA1.EventType__c = eventTypeNotSubscribed.Id;
        update PublishConfigA1;
        
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceA);
        SequenceBuilderExtension controller = new SequenceBuilderExtension(standardController);
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
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(Publish.class);
        new StepModel(stepB1).upsertConfig();
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(Wiretap.class);
        
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceB);
        SequenceBuilderExtension controller = new SequenceBuilderExtension(standardController);
        controller.findPublishProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);
        
        String expectedDescription = 'No event type has been configured';
        String actualDescription = messages[0].getSummary();
        System.assert(actualDescription.contains(expectedDescription), messages[0]);
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContaningStatusEqWarningSubscribe() {
        //arrange sequence
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        
        // Sequence A - Warning : Ok but event Not published
        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Subscribe.class);
        new StepModel(stepA1).upsertConfig();
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);

        // Event
        EventType__c eventNotPublished = new EventType__c(
            Name = 'an-event-not-published'
        );
        insert eventNotPublished;
       
        // Config A1
        Id configIdA1 = ((Step__c)ApexDomain.getById(stepA1.Id)).ConfigId__c;
        SubscribeConfig__c subscribeConfigA1 = (SubscribeConfig__c)ApexDomain.getById(configIdA1);
        subscribeConfigA1.EventType__c = eventNotPublished.Id;
        update subscribeConfigA1;
 
 
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceA);
        SequenceBuilderExtension controller = new SequenceBuilderExtension(standardController);
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
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(Wiretap.class);
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(Subscribe.class);
        new StepModel(stepB2).upsertConfig();
        
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceB);
        SequenceBuilderExtension controller = new SequenceBuilderExtension(standardController);
        controller.findSubscribeProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualSequenceSubscribeNotLastStep = sequenceB.Id;
        String expectedSequenceSubscribeNotLastStep = 'Subscribe process not first step of sequence';
        System.assert(messages[0].getSummary().contains(expectedSequenceSubscribeNotLastStep));
        System.assert(messages[0].getSummary().contains(actualSequenceSubscribeNotLastStep));
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorGtOne() {
        //arrange sequence
        Sequence__c sequenceC = new Sequence__c(Name = 'SequenceC');
        insert sequenceC;
        
        // Sequence C - Problem : Subscribe Step Occurs more than once
        Step__c stepC1 = SequenceModel.fromName(sequenceC.Name).appendStep(Subscribe.class);
        new StepModel(stepC1).upsertConfig();
        Step__c stepC2 = SequenceModel.fromName(sequenceC.Name).appendStep(Subscribe.class);
        new StepModel(stepC2).upsertConfig();
            
        // Event
        EventType__c eventNotPublished = new EventType__c(
            Name = 'an-event-not-published'
        );
        insert eventNotPublished;

        // Config C1
        Id configIdC1 = ((Step__c)ApexDomain.getById(stepC1.Id)).ConfigId__c;
        SubscribeConfig__c subscribeConfigC1 = (SubscribeConfig__c)ApexDomain.getById(configIdC1);
        subscribeConfigC1.EventType__c = eventNotPublished.Id;
        update subscribeConfigC1;

        // Config C2
        Id configIdC2 = ((Step__c)ApexDomain.getById(stepC2.Id)).ConfigId__c;
        SubscribeConfig__c subscribeConfigC2 = (SubscribeConfig__c)ApexDomain.getById(configIdC2);
        subscribeConfigC2.EventType__c = eventNotPublished.Id;
        update subscribeConfigC2;
        
        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceC);
        SequenceBuilderExtension controller = new SequenceBuilderExtension(standardController);
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
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(Subscribe.class);
        new StepModel(stepB1).upsertConfig();
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(Wiretap.class);

        // Act :
        ApexPages.StandardController standardController = new ApexPages.StandardController(sequenceB);
        SequenceBuilderExtension controller = new SequenceBuilderExtension(standardController);
        controller.findSubscribeProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);
        
        String actualDescription = sequenceB.Id;
        String expectedDescription = 'No event type defined on Subscribe Config';
        System.assert(messages[0].getSummary().contains(expectedDescription));
        System.assert(messages[0].getSummary().contains(actualDescription));
    }
}