@IsTest public class SequenceBuilderExtensionTest {
    
    static private Id setupSequence() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'SequenceBuilderExtensionTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
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
        List<ProcessModel> processes = (List<ProcessModel>)Json.deserialize(data, List<ProcessModel>.class);
        
        //assert
        Integer expectedCount = 13;
        Integer actualCount = processes.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testGetSteps() {
        //arrange sequence, controller and extension
        Id sequenceId = setupSequence();
        ApexPages.StandardController controller = new ApexPages.StandardController(new Sequence__c(Id = sequenceId, Name = 'SequenceBuilderExtensionTest'));
        SequenceBuilderExtension extension = new SequenceBuilderExtension(controller);
        
        //act
        String data = extension.getSteps();
        
        //assemble
        List<Step__c> steps = (List<Step__c>)Json.deserialize(data, List<Step__c>.class);
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = steps.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testFetchSteps() {
        //arrange
        Id sequenceId = setupSequence();
        
        //act
        List<Step__c> sequenceSteps = SequenceBuilderExtension.fetchSteps('SequenceBuilderExtensionTest');
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = sequenceSteps.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testAppendStep() {
        //arrange sequence
        Id sequenceId = setupSequence();
        
        //act
        SequenceBuilderExtension.appendStep('SequenceBuilderExtensionTest', Publish.class.getName());
        
        //assert
        List<Step__c> steps = SequenceModel.fromName('SequenceBuilderExtensionTest').fetchSteps();
        Step__c lastStep = steps.get(2);
        String expectedClassName = Publish.class.getName();
        String actualClassName = lastStep.FullyQualifiedClassName__c;
        System.assertEquals(expectedClassName, actualClassName);
    }
    
    static testmethod void testMoveStepBefore() {
        //arrange sequence
        Id sequenceId = setupSequence();
        List<Step__c> steps = SequenceModel.fromName('SequenceBuilderExtensionTest').fetchSteps();
        Step__c wiretapStep = steps.get(0);
        Step__c terminateStep = steps.get(1);
        
        //act
        SequenceBuilderExtension.moveStepBefore(terminateStep.Id, wiretapStep.Id);
        
        //assemble
        steps = SequenceModel.fromName('SequenceBuilderExtensionTest').fetchSteps();
        terminateStep = steps.get(0);
        wiretapStep = steps.get(1);
        
        //assert
        String terminateExpectedClassName = Terminate.class.getName();
        String terminateActualClassName = terminateStep.FullyQualifiedClassName__c;
        System.assertEquals(terminateExpectedClassName, terminateActualClassName);
        
        String wiretapExpectedClassName = Wiretap.class.getName();
        String wiretapActualClassName = wiretapStep.FullyQualifiedClassName__c;
        System.assertEquals(wiretapExpectedClassName, wiretapActualClassName);
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange sequence
        Id sequenceId = setupSequence();
        List<Step__c> steps = SequenceModel.fromName('SequenceBuilderExtensionTest').fetchSteps();
        Step__c wiretapStep = steps.get(0);
        Step__c terminateStep = steps.get(1);
        
        //act
        SequenceBuilderExtension.moveStepAfter(wiretapStep.Id, terminateStep.Id);
        
        //assemble
        steps = SequenceModel.fromName('SequenceBuilderExtensionTest').fetchSteps();
        terminateStep = steps.get(0);
        wiretapStep = steps.get(1);
        
        //assert
        String terminateExpectedClassName = Terminate.class.getName();
        String terminateActualClassName = terminateStep.FullyQualifiedClassName__c;
        System.assertEquals(terminateExpectedClassName, terminateActualClassName);
        
        String wiretapExpectedClassName = Wiretap.class.getName();
        String wiretapActualClassName = wiretapStep.FullyQualifiedClassName__c;
        System.assertEquals(wiretapExpectedClassName, wiretapActualClassName);
    }
    
    static testmethod void testDestroyStep() {
        //arrange
        Id sequenceId = setupSequence();
        List<Step__c> steps = SequenceModel.fromName('SequenceBuilderExtensionTest').fetchSteps();
        Step__c wiretapStep = steps.get(0);
        
        //act
        SequenceBuilderExtension.destroySteps(new List<Step__c>{wiretapStep});
        
        //assemble
        steps = SequenceModel.fromName('SequenceBuilderExtensionTest').fetchSteps();
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = steps.size();
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
        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA2 = StepModel.generateOne(sequenceA.Name, Terminate.class.getName());
        
        // Sequence B - Problem : Terminate Not last Step
        Step__c stepB1 = StepModel.generateOne(sequenceB.Name, Terminate.class.getName());
        Step__c stepB2 = StepModel.generateOne(sequenceB.Name, Wiretap.class.getName());
 
        // Sequence C - Problem : More than One Terminate
        Step__c stepC1 = StepModel.generateOne(sequenceC.Name, Terminate.class.getName());
        Step__c stepC2 = StepModel.generateOne(sequenceC.Name, Terminate.class.getName());
        
        // Sequence D - Problem : Zero Terminate
        Step__c stepD1 = StepModel.generateOne(sequenceD.Name, Wiretap.class.getName());
        Step__c stepD2 = StepModel.generateOne(sequenceD.Name, Wiretap.class.getName());

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
        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Publish.class.getName());
        Step__c stepA2 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        
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
        Step__c stepB1 = StepModel.generateOne(sequenceB.Name, Publish.class.getName());
        Step__c stepB2 = StepModel.generateOne(sequenceB.Name, Wiretap.class.getName());
        
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
        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Subscribe.class.getName());
        Step__c stepA2 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());

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
        Step__c stepB1 = StepModel.generateOne(sequenceB.Name, Wiretap.class.getName());
        Step__c stepB2 = StepModel.generateOne(sequenceB.Name, Subscribe.class.getName());
        
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
        Step__c stepC1 = StepModel.generateOne(sequenceC.Name, Subscribe.class.getName());
        Step__c stepC2 = StepModel.generateOne(sequenceC.Name, Subscribe.class.getName());
            
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
        Step__c stepB1 = StepModel.generateOne(sequenceB.Name, Subscribe.class.getName());
        Step__c stepB2 = StepModel.generateOne(sequenceB.Name, Wiretap.class.getName());

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