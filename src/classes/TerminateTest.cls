@IsTest //-- no view of org data
private class TerminateTest
{
    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 100;
        Integer actualLimits = new Terminate.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }


    static testmethod void callingExecuteReturnsExpectedOutputEventsWhenSubsequenceAttribsDefinedOnInputEvent()
    {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        String subsequenceName = 'the-subsequence';
        Decimal subsequencePosition = 2;
        
        //arrange processes
        Process__c subsequenceProcess = ProcessModel.generateOne(Subsequence.class);
        Process__c wiretapProcess = ProcessModel.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = subsequenceName);
        insert sequence;
        
        //arrange steps
        Step__c step1 = StepModel.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c step2 = StepModel.generateOne(sequence.Id, subsequenceProcess.Id);

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            '__Position' => position,
            '__SubsequenceStepIds' => new List<Id>{step2.Id},
            'data' => data
        };


        Decimal expectedSize = 1;
        String expectedSequenceName = subsequenceName;
        Decimal expectedPosition = subsequencePosition;

        // Act
        Type reflector = Terminate.class;
        List<Map<String,Object>> actualOutParametersList = new Broker.Wrapper(reflector, inputEvent).invokeMain().Outputs;

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        String actualSequenceName = null;
        Decimal actualPosition = null;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualSequenceName = (String)actualParameters.get('__SequenceName');
            actualPosition = (Decimal)actualParameters.get('__Position');
        }

        // Assert
        System.assertEquals(expectedSize, actualSize);
        System.assertEquals(expectedSequenceName, actualSequenceName);
        System.assertEquals(expectedPosition, actualPosition);
    }
    
    static testmethod void
    callingExecuteReturnsExpectedParametersCollectionWhenNoSubsequenceAttribsDefinedOnParameters() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
 
 

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            '__Position' => position,
            'data' => data
        };

        Decimal expectedSize = 0;
 
        // Act
        Type reflector = Terminate.class;
        List<Map<String,Object>> actualOutParametersList = new Broker.Wrapper(reflector, inputEvent).invokeMain().Outputs;

        // prepare
        Decimal actualSize = actualOutParametersList.size();
 
        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
    
    static testmethod void testMultipleSubsequencesGetPoppedOffStack() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        String subsequenceName = 'the-subsequence';
        Decimal subsequencePosition  = 2;

        Sequence__c sequence = new Sequence__c(Name = subsequenceName);
        insert sequence;
        
        Process__c subsequenceProcess = ProcessModel.generateOne(Subsequence.class);
        
        Step__c step01 = StepModel.generateOne(sequence.Id, subsequenceProcess.Id);
        Step__c step02 = StepModel.generateOne(sequence.Id, subsequenceProcess.Id);
        
        Id subsequenceStepId01 = step01.Id ;
        Id subsequenceStepId02 = step02.Id ;
        List<Id> subsequenceStepIds = new List<Id>();
        subsequenceStepIds.add(subsequenceStepId01);
        subsequenceStepIds.add(subsequenceStepId02);
        
        Map<String,Object> parametersFirst = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            '__Position' => position,
            '__SubsequenceStepIds' => subsequenceStepIds,
            'data' => data
        };


        // Act
        Type reflector = Terminate.class;
        List<Map<String,Object>> actualOutParametersListFirst = new Broker.Wrapper(reflector, parametersFirst).invokeMain().Outputs;
        
        Map<String,Object> parametersSecond = actualOutParametersListFirst[0].clone(); //-- Terminate hands back one
        
        List<Map<String,Object>> actualOutParametersListSecond = new Broker.Wrapper(reflector, parametersSecond).invokeMain().Outputs;
        
        // prepare
        List<Object> actualStepIdsAfterFirst = (List<Object>)actualOutParametersListFirst[0].get('__SubsequenceStepIds');
        List<Object> actualStepIdsAfterSecond = (List<Object>)actualOutParametersListSecond[0].get('__SubsequenceStepIds');
        
        Integer actualSizeAfterFirst = actualStepIdsAfterFirst.size();
        Integer actualSizeAfterSecond = actualStepIdsAfterSecond.size();
        
        Integer expectedSizeAfterFirst = 1;
        Integer expectedSizeAfterSecond = 0;
        
        // Assert
        System.assertEquals(expectedSizeAfterFirst, actualSizeAfterFirst);
        System.assertEquals(expectedSizeAfterSecond , actualSizeAfterSecond);
    }

}