@IsTest class SequenceModelTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void  callingFetchStepsReturnsExpectedStepCollection() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        Step__c stepA1 = SequenceModel.fromName(soSequence.Name).appendStep(SubscribeService.class.getName());
        Step__c stepA2 = SequenceModel.fromName(soSequence.Name).appendStep(PublishService.class.getName());
        Step__c stepA3 = SequenceModel.fromName(soSequence.Name).appendStep(TerminateService.class.getName());
        Integer positionA1 = stepA1.Position__c.intValue();
        Integer positionA2 = stepA2.Position__c.intValue();
        Integer positionA3 = stepA3.Position__c.intValue();

        // act
        SequenceModel sequence = SequenceModel.fromName(soSequence.Name);
        
        // assemble
        List<Map<String,Object>> soSteps = sequence.stepDtos();
        Integer actualStepCount = soSteps.size();

        // assert
        
        Integer expectedStepCount = 3;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    static testmethod void callingAppendStepAddStepWithExpectedServiceInExpectedPosition() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act
        Step__c actualStep = SequenceModel.fromName(soSequence.Name).appendStep(SubscribeService.class.getName());
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexTypeName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        // SObject soStep = actualStep.getRecord();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexTypeName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = SubscribeService.class.getName();
        System.assertEquals( expectedServiceName , actualServiceName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }

    static testmethod void callingTerminateAddsTerminateStepIfNoTerminateStepExists() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act
        SequenceModel sequence = SequenceModel.fromName(soSequence.Name);
        sequence.terminateIfNeeded();
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexTypeName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexTypeName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = TerminateService.class.getName();
        System.assertEquals( expectedServiceName , actualServiceName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    static testmethod void callingTerminateDoesNotAddTerminateStepIfTerminateStepExists() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act
        SequenceModel sequence = SequenceModel.fromName(soSequence.Name);
        sequence.terminateIfNeeded(); // once ( terminate will now exist)
        sequence.terminateIfNeeded(); // and again!
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexTypeName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexTypeName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = TerminateService.class.getName();
        System.assertEquals( expectedServiceName , actualServiceName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    static testmethod void callingDeleteStepWillDeleteStepOnThisSequence() {
        // arrange
        String sequenceNameA = 'theSequenceA';
        Sequence__c soSequenceA = new Sequence__c(Name = sequenceNameA);
        insert soSequenceA;
        Id soSequenceAId = soSequenceA.Id;
        Step__c stepA1 = SequenceModel.fromName(soSequenceA.Name).appendStep(SubscribeService.class.getName());
        Step__c stepA2 = SequenceModel.fromName(soSequenceA.Name).appendStep(TerminateService.class.getName());
 

        // act
        SequenceModel sequenceA = SequenceModel.fromName(soSequenceA.Name);
        SequenceModel.fromName(sequenceNameA).destroyStep(stepA1.Name);
 
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexTypeName__c, Position__c FROM Step__c];
        Integer actualStepsCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexTypeName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
   
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = TerminateService.class.getName();
        System.assertEquals( expectedServiceName , actualServiceName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepsCount  );
    }
    
    static testmethod void testStepDtos() {
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(
            Name = 'Test'
        );
        insert sequence;
        
        //arrange step
        Step__c step = new Step__c(
            IsDraft__c = true,
            Name = '1#Debugs#1',
            ConfigId__c = '015000000000000AAA',
            ConfigName__c = 'This step must be configured. Seriously.',
            ApexClassId__c = '01p000000000000AAA',
            ApexTypeName__c = 'Services.DebugService',
            Position__c = 1.0
        );
        
        step.Sequence__c = 'Test';
        insert step;
        
        //arrange model
        SequenceModel model = SequenceModel.fromName('Test');
        
        //act
        List<Map<String,Object>> dtos = model.stepDtos();
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = dtos.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedName = step.Name;
        String actualName = (String)dtos[0].get('Name');
        System.assertEquals(expectedName, actualName, 'Wrong Name.');
        
        String expectedConfigId = step.ConfigId__c;
        String actualConfigId = (String)dtos[0].get('ConfigId');
        System.assertEquals(expectedConfigId, actualConfigId, 'Wrong ConfigId.');
        
        String expectedConfigName = step.ConfigName__c;
        String actualConfigName = (String)dtos[0].get('ConfigName');
        System.assertEquals(expectedConfigName, actualConfigName, 'Wrong ConfigName.');
        
        String expectedApexClassId = step.ApexClassId__c;
        String actualApexClassId = (String)dtos[0].get('ApexClassId');
        System.assertEquals(expectedName, actualName, 'Wrong ApexClassId.');
        
        String expectedApexTypeName = step.ApexTypeName__c;
        String actualApexTypeName = (String)dtos[0].get('ApexTypeName');
        System.assertEquals(expectedApexTypeName, actualApexTypeName, 'Wrong TypeName.');
        
        Integer expectedPosition = step.Position__c.intValue();
        Integer actualPosition = (Integer)dtos[0].get('Position');
        System.assertEquals(expectedPosition, actualPosition, 'Wrong Position.');
    }
    
    static testmethod void testCountRoutedMessages() {
        //arrange sequence
        insert new Sequence__c(Name = 'Test');
        
        //arrange step
        SequenceModel.fromName('Test').appendStep(TerminateService.class.getName());
        
        //arrange message
        insert new Message__c(Event__c = '{"Route":"1#Test#1"}');
        
        //act
        Integer expectedCount = 1;
        Integer actualCount = SequenceModel.fromName('Test').countRoutedMessages();
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        
    }
    
    static testmethod void healApexTypeNames() {
        
        //arrange sequence
        insert new Sequence__c(Name = 'Test');
        
        //arrange steps
        insert new Step__c(
            Name = '1#Test#1',
            Version__c = 1,
            Sequence__c = 'Test',
            Position__c = 1,
            IsDraft__c = true,
            ApexClassId__c = [SELECT Id FROM ApexClass WHERE Name = 'TerminateService'].Id,
            ApexTypeName__c = 'WrongService'
        );
        
        //act
        SequenceModel.fromName('Test').healApexTypeNames();
        
        //assemble
        Step__c step = [SELECT Id, ApexTypeName__c FROM Step__c];
        
        //assert
        String expectedName = TerminateService.class.getName();
        String actualName = step.ApexTypeName__c;
        System.assertEquals(expectedName, actualName, 'Wrong name');
    }
    
    static testmethod void healApexClassIds() {
        
        //arrange cache
        Map<String,ApexClassModel.Definition> name2definition = new ApexClassSetModel([
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Name = 'TerminateService'
        ]).discoverDefinitions();
        
        ApexClassSetModel.saveCache(name2definition);
        
        //arrange sequence
        insert new Sequence__c(Name = 'Test');
        
        //arrange sequence
        insert new Step__c(
            Name = '1#Test#1',
            Version__c = 1,
            Sequence__c = 'Test',
            Position__c = 1,
            IsDraft__c = true,
            ApexClassId__c = '01p000000000000AAA',
            ApexTypeName__c = TerminateService.class.getName()
        );
        
        //act
        SequenceModel.fromName('Test').healApexClassIds();
        
        //assemble
        Step__c step = [SELECT Id, ApexClassId__c FROM Step__c];
        
        //assert
        Id expectedId = [SELECT Id FROM ApexClass WHERE Name = 'TerminateService'].Id;
        Id actualId = step.ApexClassId__c;
        System.assertEquals(expectedId, actualId, 'Wrong id');
    }
}