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
    
}