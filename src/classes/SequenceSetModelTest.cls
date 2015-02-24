@IsTest private class SequenceSetModelTest {

    //before delete
    static testmethod void testDeleteTriggersAreCascaded() {
        //arrange process
        Process__c branchProcess = ProcessModel.generateOne(Branch.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'testSequence');
        insert sequence;
        
        //arrange steps
        Step__c branchStep = StepModel.generateOne(sequence.Id, branchProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);
        
        Integer expectedConfigsBefore = 1;
        Integer actualConfigsBefore = [SELECT COUNT() FROM BranchConfig__c];
        
        //act
        delete sequence;
        
        Integer expectedConfigsAfter = 0;
        Integer actualConfigsAfter = [SELECT COUNT() FROM BranchConfig__c];
        
        //assert
        System.assertEquals(expectedConfigsBefore, actualConfigsBefore);
        System.assertEquals(expectedConfigsAfter, actualConfigsAfter);
    }

}