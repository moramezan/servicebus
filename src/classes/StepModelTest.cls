@IsTest class StepModelTest {
    
    static testmethod void testMoveStepBefore() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(WiretapService.class.getName());
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        StepModel step = StepModel.fromName(terminateStep.Name);
        step.moveBefore(wiretapStep.Name);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(WiretapService.class.getName());
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        StepModel step = StepModel.fromName(wiretapStep.Name);
        step.moveAfter(terminateStep.Name);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
    static testmethod void testDescribeStepConfig() {
        //arrange step
        Step__c step = new Step__c(Name = '1#Test#1', ConfigId__c = '015000000000000AAA');
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
        Step__c step = new Step__c(Name = '1#Test#1', ConfigId__c = document.Id);
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
        List<Step__c> newSteps = new List<Step__c>();
        StepModel.fromId(stepId).checkout(newSteps);
        insert newSteps;
        
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
    
    static testmethod void testDestroyConfig() {
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
        StepModel.fromId(stepId).destroyConfig();
        
        //assert
        System.assert([SELECT Id FROM Document].isEmpty(), 'Wrong empty.');
        System.assert(![SELECT Id FROM Step__c].isEmpty(), 'Wrong empty.');
    }
    
    static testmethod void testCommitWithNormalObjectConfig() {
        //arrange config
        Id configId = Database.insert(new Account(
            Name = 'Config Test'
        )).getId();
        
        //arrange step
        Id stepId = Database.insert(new Step__c(
            Name = '1#Test#1',
            ConfigId__c = configId,
            ConfigName__c = 'Config Test',
            Version__c = 1,
            Sequence__c = 'Test',
            Position__c = 1,
            IsDraft__c = false
        )).getId();
        
        //act
        List<Step__c> newSteps = new List<Step__c>();
        StepModel.fromId(stepId).checkout(newSteps);
        insert newSteps;
        
        //arrange
        Account oldConfig = [SELECT Id, Name FROM Account WHERE Id = :configId];
        Account newConfig = [SELECT Id, Name FROM Account WHERE Id != :configId];
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = [SELECT COUNT() FROM Step__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        
        String expectedOldName = 'Config Test';
        String actualOldName = oldConfig.Name;
        System.assertEquals(expectedOldName, actualOldName, 'Wrong old name.');
        
        String expectedNewName = 'Config Test';
        String actualNewName = newConfig.Name;
        System.assertEquals(expectedNewName, actualNewName, 'Wrong new name.');
    }
    
    static testmethod void testCommitWithCustomSettingConfig() {
        //arrange config
        Id configId = Database.insert(new PublishStepConfig__c(
            Name = 'Config Test',
            Topic__c = 'Test'
        )).getId();
        
        //arrange step
        Id stepId = Database.insert(new Step__c(
            Name = '1#Test#1',
            ConfigId__c = configId,
            ConfigName__c = 'Config Test',
            Version__c = 1,
            Position__c = 1,
            IsDraft__c = false
        )).getId();
        
        //act
        List<Step__c> newSteps = new List<Step__c>();
        StepModel.fromId(stepId).checkout(newSteps);
        insert newSteps;
        
        //arrange
        PublishStepConfig__c oldConfig = [SELECT Id, Name FROM PublishStepConfig__c WHERE Id = :configId];
        PublishStepConfig__c newConfig = [SELECT Id, Name FROM PublishStepConfig__c WHERE Id != :configId];
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = [SELECT COUNT() FROM Step__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        
        String expectedOldName = configId;
        String actualOldName = oldConfig.Name;
        System.assertEquals(expectedOldName, actualOldName, 'Wrong old name.');
        
        String expectedNewName = 'Config Test';
        String actualNewName = newConfig.Name;
        System.assertEquals(expectedNewName, actualNewName, 'Wrong new name.');
    }
    
    //untestable, no built in objects with Auto-Number Name
    /*static testmethod void testCommitWithAutoNumberConfig() {
        //arrange config
        Id configId = Database.insert(new Auto__c()).getId();
        
        //arrange step
        Id stepId = Database.insert(new Step__c(
            Name = '1#Test#1',
            ConfigId__c = configId,
            ConfigName__c = 'Config Test',
            Version__c = 1,
            Position__c = 1,
            IsDraft__c = false
        )).getId();
        
        //act
        StepModel.fromId(stepId).checkout();
        
        //arrange
        Auto__c oldConfig = [SELECT Id, Name FROM Auto__c WHERE Id = :configId];
        Auto__c newConfig = [SELECT Id, Name FROM Auto__c WHERE Id != :configId];
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = [SELECT COUNT() FROM Step__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        
        String expectedOldName = 'A-';
        String actualOldName = oldConfig.Name;
        System.assert(actualOldName.contains(expectedOldName), 'Wrong old name.');
        
        String expectedNewName = 'A-';
        String actualNewName = newConfig.Name;
        System.assert(actualNewName.contains(expectedNewName), 'Wrong new name.');
    }*/
    
}