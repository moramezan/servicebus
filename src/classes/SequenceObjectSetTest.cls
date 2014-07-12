@IsTest private class SequenceObjectSetTest {

    //before delete
    static testmethod void testDeleteTriggersAreCascaded() {
        //arrange process
        Process__c branchProcess = ProcessObject.generateOne(Branch.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'testSequence');
        insert sequence;
        
        //arrange steps
        Step__c branchStep = StepObject.generateOne(sequence.Id, branchProcess.Id);
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        Integer expectedConfigsBefore = 1;
        Integer actualConfigsBefore = [SELECT COUNT() FROM BranchConfiguration__c];
        
        //act
        delete sequence;
        
        Integer expectedConfigsAfter = 0;
        Integer actualConfigsAfter = [SELECT COUNT() FROM BranchConfiguration__c];
        
        //assert
        System.assertEquals(expectedConfigsBefore, actualConfigsBefore);
        System.assertEquals(expectedConfigsAfter, actualConfigsAfter);
    }

}