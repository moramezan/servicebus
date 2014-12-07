@IsTest //-- no view of org data
private class TerminateTest
{

    static testmethod void callingExecuteReturnsExpectedParametersCollectionWhenSubsequenceAttribsDefinedOnParameters()
    {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        String subsequenceName = 'the-subsequence';
        Decimal subsequencePosition = 2;
        
        //arrange processes
        Process__c subsequenceProcess = ProcessObject.generateOne(Subsequence.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = subsequenceName);
        insert sequence;
        
        //arrange steps
        Step__c step1 = StepObject.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c step2 = StepObject.generateOne(sequence.Id, subsequenceProcess.Id);

        Map<String,Object> parameters = new Map<String,Object> {
            'esb_SequenceName' => sequenceName,
            'esb_Position' => position,
            'esb_SubsequenceStepIds' => new List<Id>{step2.Id},
            'data' => data
        };


        Decimal expectedSize = 1;
        String expectedSequenceName = subsequenceName;
        Decimal expectedPosition = subsequencePosition;

        // Act
        Type reflector = Terminate.class;
        List<Map<String,Object>> actualOutParametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        String actualSequenceName = null;
        Decimal actualPosition = null;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualSequenceName = (String)actualParameters.get('esb_SequenceName');
            actualPosition = (Decimal)actualParameters.get('esb_Position');
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
 
 

        Map<String,Object> parameters = new Map<String,Object> {
            'esb_SequenceName' => sequenceName,
            'esb_Position' => position,
            'data' => data
        };

        Decimal expectedSize = 0;
 
        // Act
        Type reflector = Terminate.class;
        List<Map<String,Object>> actualOutParametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

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
        
        Process__c subsequenceProcess = ProcessObject.generateOne(Subsequence.class);
        
        Step__c step01 = StepObject.generateOne(sequence.Id, subsequenceProcess.Id);
        Step__c step02 = StepObject.generateOne(sequence.Id, subsequenceProcess.Id);
        
        Id subsequenceStepId01 = step01.Id ;
        Id subsequenceStepId02 = step02.Id ;
        List<Id> subsequenceStepIds = new List<Id>();
        subsequenceStepIds.add(subsequenceStepId01);
        subsequenceStepIds.add(subsequenceStepId02);
        
        Map<String,Object> parametersFirst = new Map<String,Object> {
            'esb_SequenceName' => sequenceName,
            'esb_Position' => position,
            'esb_SubsequenceStepIds' => subsequenceStepIds,
            'data' => data
        };


        // Act
        Type reflector = Terminate.class;
        List<Map<String,Object>> actualOutParametersListFirst = new Broker.Wrapper(reflector, parametersFirst, null).invokeMain().Outputs;
        
        Map<String,Object> parametersSecond = actualOutParametersListFirst[0].clone(); //-- Terminate hands back one
        
        List<Map<String,Object>> actualOutParametersListSecond = new Broker.Wrapper(reflector, parametersSecond, null).invokeMain().Outputs;
        
        // prepare
        List<Object> actualStepIdsAfterFirst = (List<Object>)actualOutParametersListFirst[0].get('esb_SubsequenceStepIds');
        List<Object> actualStepIdsAfterSecond = (List<Object>)actualOutParametersListSecond[0].get('esb_SubsequenceStepIds');
        
        Integer actualSizeAfterFirst = actualStepIdsAfterFirst.size();
        Integer actualSizeAfterSecond = actualStepIdsAfterSecond.size();
        
        Integer expectedSizeAfterFirst = 1;
        Integer expectedSizeAfterSecond = 0;
        
        // Assert
        System.assertEquals(expectedSizeAfterFirst, actualSizeAfterFirst);
        System.assertEquals(expectedSizeAfterSecond , actualSizeAfterSecond);
    }

}