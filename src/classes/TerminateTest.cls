@isTest //-- no view of org data
private class TerminateTest
{

    static testMethod void callingExecuteReturnsExpectedParametersCollectionWhenBoomerangAttribsDefinedOnParameters()
    {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        String boomerangSequenceName = 'boomerang-sequence';
        Decimal boomerangPosition = 2;
        
        //arrange processes
        Process__c boomerangProcess = Processes.generateOne(Boomerang.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = boomerangSequenceName);
        insert sequence;
        
        //arrange steps
        Step__c step1 = Steps.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c step2 = Steps.generateOne(sequence.Id, boomerangProcess.Id);

        Map<String,Object> parameters = new Map<String,Object> {
            'eda__sequenceName' => sequenceName,
            'eda__position' => position,
            'eda__boomerangStepIds' => new List<Id>{step2.Id},
            'data' => data
        };


        Decimal expectedSize = 1;
        String expectedSequenceName = boomerangSequenceName;
        Decimal expectedPosition = boomerangPosition;

        // Act
        Terminate terminate = new Terminate();
        Process.PluginResult results = terminate.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualOutParametersList = Utility.convert(results);

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        String actualSequenceName = null;
        Decimal actualPosition = null;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualSequenceName = (String)actualParameters.get('eda__sequenceName');
            actualPosition = (Decimal)actualParameters.get('eda__position');
        }

        // Assert
        System.assertEquals(expectedSize, actualSize);
        System.assertEquals(expectedSequenceName, actualSequenceName);
        System.assertEquals(expectedPosition, actualPosition);
    }
    
    static testMethod void
    callingExecuteReturnsExpectedParametersCollectionWhenNoBoomerangAttribsDefinedOnParameters() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
 
 

        Map<String,Object> parameters = new Map<String,Object> {
            'eda__sequenceName' => sequenceName,
            'eda__position' => position,
            'data' => data
        };

        Decimal expectedSize = 0;
 
        // Act
        Terminate terminate = new Terminate();
        Process.PluginResult results = terminate.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualOutParametersList = Utility.convert(results);

        // prepare
        Decimal actualSize = actualOutParametersList.size();
 
        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
    
    static testMethod void testMultipleBoomerangsGetPoppedOffStack() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        String boomerangSequenceName = 'boomerang-sequence';
        Decimal boomerangPosition  = 2;

        Sequence__c sequence = new Sequence__c(Name = boomerangSequenceName);
        insert sequence;
        
        Process__c process = Processes.generateOne(Boomerang.class);
        
        Step__c step01 = Steps.generateOne(sequence.Id, process.Id);
        Step__c step02 = Steps.generateOne(sequence.Id, process.Id);
        
        Id boomerangStepId01 = step01.Id ;
        Id boomerangStepId02 = step02.Id ;
        List<Id> boomerangStepIds = new List<Id>();
        boomerangStepIds.add(boomerangStepId01);
        boomerangStepIds.add(boomerangStepId02);
        
        Map<String,Object> parametersFirst = new Map<String,Object> {
            'eda__sequenceName' => sequenceName,
            'eda__position' => position,
            'eda__boomerangStepIds' => boomerangStepIds,
            'data' => data
        };


        // Act
        Terminate terminate = new Terminate();
        
        Process.PluginResult resultsInvokeFirst = terminate.invoke(new Process.PluginRequest(parametersFirst));
        List<Map<String,Object>> actualOutParametersListFirst = Utility.convert(resultsInvokeFirst);
        
        Map<String,Object> parametersSecond = actualOutParametersListFirst[0].clone(); //-- Terminate hands back one
        
        Process.PluginResult resultsInvokeSecond = terminate.invoke(new Process.PluginRequest(parametersSecond));
        List<Map<String,Object>> actualOutParametersListSecond = Utility.convert(resultsInvokeSecond);
        
        // prepare
        List<Object> actualStepIdsAfterFirst = (List<Object>)actualOutParametersListFirst[0].get('eda__boomerangStepIds');
        List<Object> actualStepIdsAfterSecond = (List<Object>)actualOutParametersListSecond[0].get('eda__boomerangStepIds');
        
        Integer actualSizeAfterFirst = actualStepIdsAfterFirst.size();
        Integer actualSizeAfterSecond = actualStepIdsAfterSecond.size();
        
        Integer expectedSizeAfterFirst = 1;
        Integer expectedSizeAfterSecond = 0;
        
        // Assert
        System.assertEquals(expectedSizeAfterFirst, actualSizeAfterFirst);
        System.assertEquals(expectedSizeAfterSecond , actualSizeAfterSecond);
    }
    
    static testMethod void callingGetHeathReturnsExpectedList() {
        // #11 : Trivial error / health checker
        // * Sequence with no Terminate (error)
        // * Sequence with more than one Terminate (error)
        // * Terminate that's not at the end (error)
        
        // Arrange :
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        Sequence__c sequenceC = new Sequence__c(Name = 'SequenceC');
        insert sequenceC;
        Sequence__c sequenceD = new Sequence__c(Name = 'SequenceD');
        insert sequenceD;
        
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        // Sequence A - Ok
        Step__c stepA1 = Steps.generateOne(sequenceA.Id, wireTapProcess.Id);
        Step__c stepA2 = Steps.generateOne(sequenceA.Id, terminateProcess.Id);
        
        // Sequence B - Problem : Terminate Not last Step
        Step__c stepB1 = Steps.generateOne(sequenceB.Id, terminateProcess.Id);
        Step__c stepB2 = Steps.generateOne(sequenceB.Id, wireTapProcess.Id);
 
        // Sequence C - Problem : More than One Terminate
        Step__c stepC1 = Steps.generateOne(sequenceC.Id, terminateProcess.Id);
        Step__c stepC2 = Steps.generateOne(sequenceC.Id, terminateProcess.Id);
        
        // Sequence D - Problem : Zero Terminate
        Step__c stepD1 = Steps.generateOne(sequenceD.Id, wireTapProcess.Id);
        Step__c stepD2 = Steps.generateOne(sequenceD.Id, wireTapProcess.Id);

        // Act :
        List<HealthController.Health> terminateHealths =  Terminate.getHealth();
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualOkCount = 0;
        Integer actualErrorCount = 0;
        for (HealthController.Health terminateHealth : terminateHealths ) {
            sequenceIdToDescription.put(terminateHealth.SequenceId, terminateHealth.Detail);
            if (terminateHealth.Status == 'Ok') {
                actualOkCount++;
            }
            if (terminateHealth.Status == 'Error') {
                actualErrorCount++;
            }
        }
        
        // Assert :
        Integer expectedCount = 4;
        Integer actualCount = terminateHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedOkCount = 1;
        System.assertEquals(expectedOkCount, actualOkCount);
        
        Integer expectedErrorCount = 3;
        System.assertEquals(expectedErrorCount, actualErrorCount);
        
        String actualSequenceTerminateNotLastStep = sequenceIdToDescription.get(sequenceB.Id);
        String expectedSequenceTerminateNotLastStep = 'Terminate process not present at end of sequence';
        System.assertEquals(expectedSequenceTerminateNotLastStep, actualSequenceTerminateNotLastStep);
        
        String actualSequenceMoreThanOneTerminate = sequenceIdToDescription.get(sequenceC.Id);
        String expectedSequenceMoreThanOneTerminate ='More than one Terminate found in sequence';
        System.assertEquals(expectedSequenceMoreThanOneTerminate, actualSequenceMoreThanOneTerminate);
        
        String actualSequenceZeroTerminates = sequenceIdToDescription.get(sequenceD.Id);
        String  expectedSequenceZeroTerminates =  'No Terminate found in sequence';
        System.assertEquals(expectedSequenceZeroTerminates, actualSequenceZeroTerminates);
    }

    
    static testMethod void callingGetHeathReturnsExpectedListWhenTerminateNotDefined() {
        
        // Arrange :
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
 
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;
        
        // Sequence A - Error but Terminate process not defined
        Step__c stepA1 =  new Step__c(Sequence__c = sequenceA.Id, Process__c = wireTapProcess.Id, Position__c  = 1);
        Step__c stepA2 =  new Step__c(Sequence__c = sequenceA.Id, Process__c = wireTapProcess.Id, Position__c = 2);

        // Act :
        List<HealthController.Health> terminateHealths =  Terminate.getHealth();
        
        // Assemble :
        Map<id,string> sequenceIdToDescription = new Map<id,string>();
        Integer actualOkCount = 0;
        Integer actualUnknownCount = 0;
        for (HealthController.Health terminateHealth : terminateHealths ) {
            sequenceIdToDescription.put(terminateHealth.SequenceId, terminateHealth.Detail);
            if (terminateHealth.Status == 'Ok') {
                actualOkCount++;
            }
            if (terminateHealth.Status == 'Unknown') {
                actualUnknownCount++;
            }
        }
        
        // Assert :
        Integer expectedCount = 1;
        Integer actualCount = terminateHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedOkCount = 0;
        System.assertEquals(expectedOkCount, actualOkCount);
        
        Integer expectedUnknownCount = 1;
        System.assertEquals(expectedUnknownCount, actualUnknownCount);
        
        String actualUnknown = sequenceIdToDescription.get(sequenceA.Id);
        String expectedUnknown = 'Cannot resolve Id of Terminate process';
        System.assertEquals(expectedUnknown, actualUnknown);
    }
}