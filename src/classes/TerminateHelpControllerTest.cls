@IsTest public class TerminateHelpControllerTest{
    
    static testMethod void callingGetHeathReturnsExpectedList() {
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
        
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        
        // Sequence A - Ok
        Step__c stepA1 = StepObjectSet.generateOne(sequenceA.Id, wireTapProcess.Id);
        Step__c stepA2 = StepObjectSet.generateOne(sequenceA.Id, terminateProcess.Id);
        
        // Sequence B - Problem : Terminate Not last Step
        Step__c stepB1 = StepObjectSet.generateOne(sequenceB.Id, terminateProcess.Id);
        Step__c stepB2 = StepObjectSet.generateOne(sequenceB.Id, wireTapProcess.Id);
 
        // Sequence C - Problem : More than One Terminate
        Step__c stepC1 = StepObjectSet.generateOne(sequenceC.Id, terminateProcess.Id);
        Step__c stepC2 = StepObjectSet.generateOne(sequenceC.Id, terminateProcess.Id);
        
        // Sequence D - Problem : Zero Terminate
        Step__c stepD1 = StepObjectSet.generateOne(sequenceD.Id, wireTapProcess.Id);
        Step__c stepD2 = StepObjectSet.generateOne(sequenceD.Id, wireTapProcess.Id);

        // Act :
        TerminateHelpController controller = new TerminateHelpController();
        controller.findProblems();
        
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

}