@IsTest class SequenceModelTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().upsertNamespaceSetting();
        
        //assert
        System.assertNotEquals(null, NamespaceSetting__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void  callingFetchStepsReturnsExpectedStepCollection() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        Step__c stepA1 = SequenceModel.fromName(soSequence.Name).appendStep(Subscribe.class);
        Step__c stepA2 = SequenceModel.fromName(soSequence.Name).appendStep(Publish.class);
        Step__c stepA3 = SequenceModel.fromName(soSequence.Name).appendStep(Terminate.class);
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
        Step__c actualStep = SequenceModel.fromName(soSequence.Name).appendStep(Subscribe.class);
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexClassName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        // SObject soStep = actualStep.getRecord();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexClassName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = Subscribe.class.getName();
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
        List<Step__c> soSteps = [SELECT Name, ApexClassName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexClassName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = Terminate.class.getName();
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
        List<Step__c> soSteps = [SELECT Name, ApexClassName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexClassName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = Terminate.class.getName();
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
        Step__c stepA1 = SequenceModel.fromName(soSequenceA.Name).appendStep(Subscribe.class);
        Step__c stepA2 = SequenceModel.fromName(soSequenceA.Name).appendStep(Terminate.class);
 

        // act
        SequenceModel sequenceA = SequenceModel.fromName(soSequenceA.Name);
        SequenceModel.fromName(sequenceNameA).destroyStep(stepA1.Name);
 
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexClassName__c, Position__c FROM Step__c];
        Integer actualStepsCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexClassName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
   
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = Terminate.class.getName();
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
            Name = '1#Wiretaps#1',
            ConfigId__c = '015000000000000AAA',
            ConfigName__c = 'This step must be configured. Seriously.',
            ApexClassId__c = '01p000000000000AAA',
            ApexClassName__c = 'servicebus.Wiretap',
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
        
        String expectedApexClassName = step.ApexClassName__c;
        String actualApexClassName = (String)dtos[0].get('ApexClassName');
        System.assertEquals(expectedApexClassName, actualApexClassName, 'Wrong ApexClassName.');
        
        Integer expectedPosition = step.Position__c.intValue();
        Integer actualPosition = (Integer)dtos[0].get('Position');
        System.assertEquals(expectedPosition, actualPosition, 'Wrong Position.');
    }
}