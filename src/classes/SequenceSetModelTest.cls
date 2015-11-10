@IsTest class SequenceSetModelTest {

    //before delete
    static testmethod void testDeleteTriggersAreCascaded() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
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
        
        Step__c scheduleStep = SequenceModel.fromId(sequence.Id).appendStep(ScheduleDaily.class);
        Id configId = new stepModel(scheduleStep).upsertConfig();
        Step__c terminateStep = SequenceModel.fromId(sequence.Id).appendStep(Terminate.class);
        
        //act
        Database.delete(configId);
        delete sequence;
        
        Integer expectedCount = 0;
        Integer actualCount = [SELECT COUNT() FROM Step__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong step count.');
    }
    
    static testmethod void testLocateDraftSteps() {
        //arrange
        insert new Step__c(Name = '1#Test#1', IsDraft__c = false);
        insert new Step__c(Name = '1#Test#2', IsDraft__c = false);
        insert new Step__c(Name = '1#Test#3', IsDraft__c = false);
        insert new Step__c(Name = '2#Test#1', IsDraft__c = true);
        insert new Step__c(Name = '2#Test#2', IsDraft__c = true);
        insert new Step__c(Name = '2#Test#3', IsDraft__c = true);
        
        //act
        Database.QueryLocatorIterator iterator = SequenceSetModel.locateDraftSteps().iterator();
        
        //assemble
        Step__c step1 = (Step__c)iterator.next();
        Step__c step2 = (Step__c)iterator.next();
        Step__c step3 = (Step__c)iterator.next();
        
        //assert
        System.assertEquals('2#Test#1', step1.Name, 'Wrong name.');
        System.assertEquals('2#Test#2', step2.Name, 'Wrong name.');
        System.assertEquals('2#Test#3', step3.Name, 'Wrong name.');
        System.assert(!iterator.hasNext());
    }
    
    static testmethod void testLocateLiveSteps() {
        //arrange
        insert new Step__c(Name = '1#Test#1', Version__c = 1, IsDraft__c = false);
        insert new Step__c(Name = '1#Test#2', Version__c = 1, IsDraft__c = false);
        insert new Step__c(Name = '1#Test#3', Version__c = 1, IsDraft__c = false);
        insert new Step__c(Name = '2#Test#1', Version__c = 2, IsDraft__c = true);
        insert new Step__c(Name = '2#Test#2', Version__c = 2, IsDraft__c = true);
        insert new Step__c(Name = '2#Test#3', Version__c = 2, IsDraft__c = true);
        
        //act
        Database.QueryLocatorIterator iterator = SequenceSetModel.locateLiveSteps().iterator();
        
        //assemble
        Step__c step1 = (Step__c)iterator.next();
        Step__c step2 = (Step__c)iterator.next();
        Step__c step3 = (Step__c)iterator.next();
        
        //assert
        System.assertEquals('1#Test#1', step1.Name, 'Wrong name.');
        System.assertEquals('1#Test#2', step2.Name, 'Wrong name.');
        System.assertEquals('1#Test#3', step3.Name, 'Wrong name.');
        System.assert(!iterator.hasNext());
    }
    
    static testmethod void testCheckoutDraft() {
        try {
            //act
            SequenceSetModel.checkoutDraft();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Nothing to checkout.', e.getMessage(), 'Wrong message');
        }
        
        //arrange
        insert new Step__c(
            Name = '1#Test#1',
            Version__c = 1,
            Sequence__c = 'Test',
            Position__c = 1,
            IsDraft__c = false
        );
        
        //act
        Test.startTest();
        Id asyncApexJobId = SequenceSetModel.checkoutDraft();
        Test.stopTest();
        
        //assemble
        Step__c step = [SELECT Name FROM Step__c WHERE IsDraft__c = true];
        
        //assert
        System.assertEquals('2#Test#1', step.Name, 'Wrong name.');
        
        try {
            //act
            SequenceSetModel.checkoutDraft();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Already checked out.', e.getMessage(), 'Wrong message');
        }
    }
    
    static testmethod void testShowSequences() {
        try {
            //act
            SequenceSetModel.showSequences();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Nothing to show.', e.getMessage(), 'Wrong message.');
        }
        
        //arrange
        insert new Step__c(Name = '1#Herp#1', Version__c = 1, Sequence__c = 'Herp', Position__c = 1, IsDraft__c = false);
        insert new Step__c(Name = '1#Herp#2', Version__c = 1, Sequence__c = 'Herp', Position__c = 2, IsDraft__c = false);
        insert new Step__c(Name = '1#Herp#3', Version__c = 1, Sequence__c = 'Herp', Position__c = 3, IsDraft__c = false);
        insert new Step__c(Name = '2#Derp#1', Version__c = 1, Sequence__c = 'Derp', Position__c = 1, IsDraft__c = true);
        insert new Step__c(Name = '2#Derp#2', Version__c = 1, Sequence__c = 'Derp', Position__c = 2, IsDraft__c = true);
        insert new Step__c(Name = '2#Derp#3', Version__c = 1, Sequence__c = 'Derp', Position__c = 3, IsDraft__c = true);
        
        //act
        SequenceSetModel.showSequences();
        
        //assemble
        Sequence__c sequence = [SELECT Name FROM Sequence__c];
        
        //assert
        System.assertEquals('Derp', sequence.Name, 'Wrong name.');
        
        try {
            //act
            SequenceSetModel.showSequences();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Already showing sequences.', e.getMessage(), 'Wrong message.');
        }
    }
    
    static testmethod void testCommitDraft() {
        try {
            //act
            SequenceSetModel.commitDraft();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Nothing to commit.', e.getMessage(), 'Wrong message.');
        }
        
        //arrange
        insert new Step__c(Name = '1#Derp#1', Version__c = 1, Sequence__c = 'Derp', Position__c = 1, IsDraft__c = true);
        insert new Sequence__c(Name = 'Derp');
        
        //act
        Test.startTest();
        SequenceSetModel.commitDraft();
        Test.stopTest();
        
        //assemble
        Step__c step = [SELECT Version__c, IsDraft__c FROM Step__c WHERE Name = '1#Derp#1'];
        
        //assert
        System.assert(!step.IsDraft__c, 'Wrong draft.');
        System.assertEquals(1, step.Version__c, 'Wrong version.');
        System.assert([SELECT Id FROM Sequence__c].isEmpty(), 'Wrong empty.');
    }
    
    static testmethod void testHideSequences() {
        try {
            //act
            SequenceSetModel.hideSequences();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Already hiding sequences.', e.getMessage(), 'Wrong message.');
        }
        
        //arrange
        insert new Sequence__c(Name = 'Test');
        
        //act
        SequenceSetModel.hideSequences();
        
        //assert
        System.assert([SELECT Id FROM Sequence__c].isEmpty(), 'Wrong empty.');
        
        try {
            //act
            SequenceSetModel.hideSequences();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Already hiding sequences.', e.getMessage(), 'Wrong message.');
        }
    }
    
    static testmethod void testDiscardDraft() {
        try {
            //act
            SequenceSetModel.discardDraft();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Nothing to discard.', e.getMessage(), 'Wrong message.');
        }
        
        //arrange
        insert new Step__c(Name = '1#Test#1', IsDraft__c = true);
        insert new Sequence__c(Name = 'Test');
        
        //act
        Test.startTest();
        SequenceSetModel.discardDraft();
        Test.stopTest();
        
        //assert
        System.assert([SELECT Id FROM Step__c].isEmpty(), 'Wrong empty.');
        System.assert([SELECT Id FROM Sequence__c].isEmpty(), 'Wrong empty.');
        
        try {
            //act
            SequenceSetModel.discardDraft();
        } catch (SequenceSetModel.ModelException e) {
            //assert
            System.assertEquals('Nothing to discard.', e.getMessage(), 'Wrong message.');
        }
    }
    
}