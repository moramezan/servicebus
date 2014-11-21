@IsTest public class SequenceBuilderExtensionTest {
    
    static private Id setupSequence() {
        //arrange processes
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'SequenceBuilderExtensionTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepObject.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        return sequence.Id;
    }
    
    static testmethod void testGetProcesses() {
        //arrange sequence, controller and extension
        Id sequenceId = setupSequence();
        ApexPages.StandardController controller = new ApexPages.StandardController(new Sequence__c(Id = sequenceId));
        SequenceBuilderExtension extension = new SequenceBuilderExtension(controller);
        
        //act
        String data = extension.getProcesses();
        
        //assemble
        List<Process__c> processes = (List<Process__c>)Json.deserialize(data, List<Process__c>.class);
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = processes.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testGetSteps() {
        //arrange sequence, controller and extension
        Id sequenceId = setupSequence();
        ApexPages.StandardController controller = new ApexPages.StandardController(new Sequence__c(Id = sequenceId));
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
        List<Step__c> sequenceSteps = SequenceBuilderExtension.fetchSteps(sequenceId);
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = sequenceSteps.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testAppendStep() {
        //arrange sequence
        Id sequenceId = setupSequence();
        
        //arrange process to append
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        //act
        SequenceBuilderExtension.appendStep(sequenceId, publishProcess.Id);
        
        //assert
        List<Step__c> steps = new SequenceObject(new Sequence__c(Id = sequenceId)).fetchSteps().getSObjects();
        Step__c lastStep = steps.get(2);
        String expectedClassName = Publish.class.getName();
        String actualClassName = lastStep.Process__r.FullyQualifiedClassName__c;
        System.assertEquals(expectedClassName, actualClassName);
    }
    
    static testmethod void testMoveStepBefore() {
        //arrange sequence
        Id sequenceId = setupSequence();
        List<Step__c> steps = new SequenceObject(new Sequence__c(Id = sequenceId)).fetchSteps().getSObjects();
        Step__c wiretapStep = steps.get(0);
        Step__c terminateStep = steps.get(1);
        
        //act
        SequenceBuilderExtension.moveStepBefore(terminateStep.Id, wiretapStep.Id);
        
        //assemble
        steps = new SequenceObject(new Sequence__c(Id = sequenceId)).fetchSteps().getSObjects();
        terminateStep = steps.get(0);
        wiretapStep = steps.get(1);
        
        //assert
        String terminateExpectedClassName = Terminate.class.getName();
        String terminateActualClassName = terminateStep.Process__r.FullyQualifiedClassName__c;
        System.assertEquals(terminateExpectedClassName, terminateActualClassName);
        
        String wiretapExpectedClassName = Wiretap.class.getName();
        String wiretapActualClassName = wiretapStep.Process__r.FullyQualifiedClassName__c;
        System.assertEquals(wiretapExpectedClassName, wiretapActualClassName);
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange sequence
        Id sequenceId = setupSequence();
        List<Step__c> steps = new SequenceObject(new Sequence__c(Id = sequenceId)).fetchSteps().getSObjects();
        Step__c wiretapStep = steps.get(0);
        Step__c terminateStep = steps.get(1);
        
        //act
        SequenceBuilderExtension.moveStepAfter(wiretapStep.Id, terminateStep.Id);
        
        //assemble
        steps = new SequenceObject(new Sequence__c(Id = sequenceId)).fetchSteps().getSObjects();
        terminateStep = steps.get(0);
        wiretapStep = steps.get(1);
        
        //assert
        String terminateExpectedClassName = Terminate.class.getName();
        String terminateActualClassName = terminateStep.Process__r.FullyQualifiedClassName__c;
        System.assertEquals(terminateExpectedClassName, terminateActualClassName);
        
        String wiretapExpectedClassName = Wiretap.class.getName();
        String wiretapActualClassName = wiretapStep.Process__r.FullyQualifiedClassName__c;
        System.assertEquals(wiretapExpectedClassName, wiretapActualClassName);
    }
    
    static testmethod void testDestroyStep() {
        //arrange
        Id sequenceId = setupSequence();
        List<Step__c> steps = new SequenceObject(new Sequence__c(Id = sequenceId)).fetchSteps().getSObjects();
        Step__c wiretapStep = steps.get(0);
        
        //act
        SequenceBuilderExtension.destroySteps(new List<Step__c>{wiretapStep});
        
        //assemble
        steps = new SequenceObject(new Sequence__c(Id = sequenceId)).fetchSteps().getSObjects();
        
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
        
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        
        // Sequence A - Ok
        Step__c stepA1 = StepObject.generateOne(sequenceA.Id, wireTapProcess.Id);
        Step__c stepA2 = StepObject.generateOne(sequenceA.Id, terminateProcess.Id);
        
        // Sequence B - Problem : Terminate Not last Step
        Step__c stepB1 = StepObject.generateOne(sequenceB.Id, terminateProcess.Id);
        Step__c stepB2 = StepObject.generateOne(sequenceB.Id, wireTapProcess.Id);
 
        // Sequence C - Problem : More than One Terminate
        Step__c stepC1 = StepObject.generateOne(sequenceC.Id, terminateProcess.Id);
        Step__c stepC2 = StepObject.generateOne(sequenceC.Id, terminateProcess.Id);
        
        // Sequence D - Problem : Zero Terminate
        Step__c stepD1 = StepObject.generateOne(sequenceD.Id, wireTapProcess.Id);
        Step__c stepD2 = StepObject.generateOne(sequenceD.Id, wireTapProcess.Id);

        // Act :
        SequenceBuilderExtension controller = new SequenceBuilderExtension(null);
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
        
        //arrange proceses
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        // Sequence A - Warning : Ok but event Not Subscribed
        Step__c stepA1 = StepObject.generateOne(sequenceA.Id, publishProcess.Id);
        Step__c stepA2 = StepObject.generateOne(sequenceA.Id, wiretapProcess.Id);
        
        // Event
        EventType__c eventTypeNotSubscribed = new EventType__c(
            Name = 'an-event-not-Subscribed'
        );
        insert eventTypeNotSubscribed;
        
        // Config A1
        Id configIdA1 = ((Step__c)SalesforceObject.getById(stepA1.Id)).ConfigId__c;
        
        PublishConfig__c PublishConfigA1 = (PublishConfig__c)SalesforceObject.getById(configIdA1);
        
        PublishConfigA1.EventType__c = eventTypeNotSubscribed.Id;
        update PublishConfigA1;
        
        // Act :
        SequenceBuilderExtension controller = new SequenceBuilderExtension(null);
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
        
        //arrange processes
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        // Sequence B - Problem : No Config
        Step__c stepB1 = StepObject.generateOne(sequenceB.Id, publishProcess.Id);
        Step__c stepB2 = StepObject.generateOne(sequenceB.Id, wiretapProcess.Id);
        
        // Act :
        SequenceBuilderExtension controller = new SequenceBuilderExtension(null);
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
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        
        // Sequence A - Warning : Ok but event Not published
        Step__c stepA1 = StepObject.generateOne(sequenceA.Id, subscribeProcess.Id);
        Step__c stepA2 = StepObject.generateOne(sequenceA.Id, wiretapProcess.Id);

        // Event
        EventType__c eventNotPublished = new EventType__c(
            Name = 'an-event-not-published'
        );
        insert eventNotPublished;
       
        // Config A1
        Id configIdA1 = ((Step__c)SalesforceObject.getById(stepA1.Id)).ConfigId__c;
        SubscribeConfig__c subscribeConfigA1 = (SubscribeConfig__c)SalesforceObject.getById(configIdA1);
        subscribeConfigA1.EventType__c = eventNotPublished.Id;
        update subscribeConfigA1;
 
 
        // Act :
        SequenceBuilderExtension controller = new SequenceBuilderExtension(null);
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
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : Subscribe Not first Step
        Step__c stepB1 = StepObject.generateOne(sequenceB.Id, wiretapProcess.Id);
        Step__c stepB2 = StepObject.generateOne(sequenceB.Id, subscribeProcess.Id);
        
        // Act :
        SequenceBuilderExtension controller = new SequenceBuilderExtension(null);
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
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        
        //arrange sequence
        Sequence__c sequenceC = new Sequence__c(Name = 'SequenceC');
        insert sequenceC;
        
        // Sequence C - Problem : Subscribe Step Occurs more than once
        Step__c stepC1 = StepObject.generateOne(sequenceC.Id, subscribeProcess.Id);
        Step__c stepC2 = StepObject.generateOne(sequenceC.Id, subscribeProcess.Id);
            
        // Event
        EventType__c eventNotPublished = new EventType__c(
            Name = 'an-event-not-published'
        );
        insert eventNotPublished;

        // Config C1
        Id configIdC1 = ((Step__c)SalesforceObject.getById(stepC1.Id)).ConfigId__c;
        SubscribeConfig__c subscribeConfigC1 = (SubscribeConfig__c)SalesforceObject.getById(configIdC1);
        subscribeConfigC1.EventType__c = eventNotPublished.Id;
        update subscribeConfigC1;

        // Config C2
        Id configIdC2 = ((Step__c)SalesforceObject.getById(stepC2.Id)).ConfigId__c;
        SubscribeConfig__c subscribeConfigC2 = (SubscribeConfig__c)SalesforceObject.getById(configIdC2);
        subscribeConfigC2.EventType__c = eventNotPublished.Id;
        update subscribeConfigC2;
        
        // Act :
        SequenceBuilderExtension controller = new SequenceBuilderExtension(null);
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
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : No Config
        Step__c stepB1 = StepObject.generateOne(sequenceB.Id, subscribeProcess.Id);
        Step__c stepB2 = StepObject.generateOne(sequenceB.Id, wiretapProcess.Id);

        // Act :
        SequenceBuilderExtension controller = new SequenceBuilderExtension(null);
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