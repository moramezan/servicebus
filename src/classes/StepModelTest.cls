@IsTest public class StepModelTest {
    
    static testmethod void testMoveStepBefore() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c.intValue());
        System.assertEquals(2, terminateStep.Position__c.intValue());
            
        //act
        StepModel step = StepModel.fromName(terminateStep.Name);
        step.moveBefore(wiretapStep.Name);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c.intValue());
        System.assertEquals(2, wiretapStep.Position__c.intValue());
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c.intValue());
        System.assertEquals(2, terminateStep.Position__c.intValue());
            
        //act
        StepModel step = StepModel.fromName(wiretapStep.Name);
        step.moveAfter(terminateStep.Name);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c.intValue());
        System.assertEquals(2, wiretapStep.Position__c.intValue());
    }
    
    static testmethod void testDescribeStepConfig() {
        //arrange step
        Step__c step = new Step__c(Name = 'Test#1', ConfigId__c = '015000000000000AAA');
        insert step;
        
        //act
        StepModel model = StepModel.fromId(step.Id);
        PageReference view = model.showConfig();
        
        //assert
        String expectedUrl = '/015000000000000?isdtp=vw';
        String actualUrl = view.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong url.');
    }
    
    static testmethod void testPersistConfigNameOnStep() {
        //arrange config
        Document document = new Document(Name = 'Test', FolderId = UserInfo.getUserId());
        insert document;
        
        //arrange step
        Step__c step = new Step__c(Name = 'Test#1', ConfigId__c = document.Id);
        insert step;
        
        //act
        new StepModel(step).persistConfigNameOnStep();
        
        //assemble
        step = [SELECT Id, ConfigName__c FROM Step__c WHERE Id = :step.Id];
        
        //assert
        String expectedName = 'Test';
        String actualName = step.ConfigName__c;
        System.assertEquals(expectedName, actualName, 'Wrong name.');
    }
    
    static testmethod void testCheckout() {
        //arrange
        Id stepId = Database.insert(new Step__c(
            Name = '1#Test#1',
            Version__c = 1,
            Sequence__c = 'Test',
            Position__c = 1,
            IsDraft__c = false
        )).getId();
        
        //act
        StepModel.fromId(stepId).checkout();
        
        //arrange
        Step__c step = [SELECT Name, Version__c, Sequence__c, Position__c, IsDraft__c FROM Step__c WHERE IsDraft__c = true];
        
        //act
        System.assertEquals('2#Test#1', step.Name, 'Wrong name.');
        System.assertEquals(2, step.Version__c, 'Wrong version.');
        System.assertEquals('Test', step.Sequence__c, 'Wrong sequence.');
        System.assertEquals(1, step.Position__c, 'Wrong position.');
        System.assertEquals(true, step.IsDraft__c, 'Wrong draft.');
    }
    
    static testmethod void testCommit() {
        //arrange
        Id stepId = Database.insert(new Step__c(
            Name = '1#Test#1',
            Version__c = 1,
            Sequence__c = 'Test',
            Position__c = 1,
            IsDraft__c = true
        )).getId();
        
        //act
        StepModel.fromId(stepId).commits();
        
        //assemble
        Step__c step = [SELECT Name, Version__c, Sequence__c, Position__c, IsDraft__c FROM Step__c];
        
        //assert
        System.assertEquals('1#Test#1', step.Name, 'Wrong name.');
        System.assertEquals(1, step.Version__c, 'Wrong version.');
        System.assertEquals('Test', step.Sequence__c, 'Wrong sequence.');
        System.assertEquals(1, step.Position__c, 'Wrong position.');
        System.assertEquals(false, step.IsDraft__c, 'Wrong draft.');
    }
    
    static testmethod void testDiscard() {
        //arrange
        Id documentId = Database.insert(new Document(
            Name = 'Test',
            FolderId = UserInfo.getUserId()
        )).getId();
        
        Id stepId = Database.insert(new Step__c(
            Name = '1#Test#1',
            ConfigId__c = documentId
        )).getId();
        
        //act
        StepModel.fromId(stepId).discard();
        
        //assert
        System.assert([SELECT Id FROM Document].isEmpty(), 'Wrong empty.');
        System.assert([SELECT Id FROM Step__c].isEmpty(), 'Wrong empty.');
    }
    
}