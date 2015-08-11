@IsTest private class SequenceSetModelTest {

    //before delete
    static testmethod void testDeleteTriggersAreCascaded() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'testSequence');
        insert sequence;
        
        //arrange steps
        Step__c branchStep = SequenceModel.fromName(sequence.Name).appendStep(Branch.class);
        new StepModel(branchStep).upsertConfig();
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
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
    
    static testmethod void testMissingIdsDontAffectDelete() {
        //arrange sequence, steps, configs
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c scheduleStep = SequenceModel.fromId(sequence.Id).appendStep(Schedule.class);
        Id configId = new stepModel(scheduleStep).upsertConfig();
        Step__c terminateStep = SequenceModel.fromId(sequence.Id).appendStep(Terminate.class);
        
        //act
        Database.delete(configId);
        delete sequence;
        
        Integer expectedCount = 0;
        Integer actualCount = [SELECT COUNT() FROM Step__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong step count.');
    }

}