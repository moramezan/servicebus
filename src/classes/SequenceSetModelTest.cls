@IsTest private class SequenceSetModelTest {

    //before delete
    static testmethod void testDeleteTriggersAreCascaded() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'testSequence');
        insert sequence;
        
        //arrange steps
        Step__c branchStep = StepModel.generateOne(sequence.Name, Branch.class.getName());
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
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