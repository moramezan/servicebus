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
        Integer position = 1;
        String data = 'data';
        String subsequenceName = 'the-subsequence';
        Integer subsequencePosition = 2;
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = subsequenceName);
        insert sequence;
        
        //arrange steps
        Step__c step1 = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c step2 = SequenceModel.fromName(sequence.Name).appendStep(Subsequence.class);

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            '__Position' => position,
            '__SubsequenceStepIds' => new List<Id>{step2.Id},
            'data' => data
        };


        Integer expectedSize = 1;
        String expectedSequenceName = subsequenceName;
        Integer expectedPosition = subsequencePosition;

        // Act
        ApexClassModel.BaseProcess process = new Terminate();
        List<Map<String,Object>> actualOutParametersList = process.execute(inputEvent);

        // prepare
        Integer actualSize = actualOutParametersList.size();
        String actualSequenceName = null;
        Integer actualPosition = null;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualSequenceName = (String)actualParameters.get('__SequenceName');
            actualPosition = (Integer)actualParameters.get('__Position');
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
        Integer position = 1;
        String data = 'data';
 
 

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            '__Position' => position,
            'data' => data
        };

        Integer expectedSize = 0;
 
        // Act
        ApexClassModel.BaseProcess process = new Terminate();
        List<Map<String,Object>> actualOutParametersList = process.execute(inputEvent);

        // prepare
        Integer actualSize = actualOutParametersList.size();
 
        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
    
    static testmethod void testMultipleSubsequencesGetPoppedOffStack() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer position = 1;
        String data = 'data';
        String subsequenceName = 'the-subsequence';
        Integer subsequencePosition  = 2;

        Sequence__c sequence = new Sequence__c(Name = subsequenceName);
        insert sequence;
        
        Step__c step02 = SequenceModel.fromName(sequence.Name).appendStep(Subsequence.class);
        Step__c step01 = SequenceModel.fromName(sequence.Name).appendStep(Subsequence.class);
        
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
        ApexClassModel.BaseProcess process = new Terminate();
        List<Map<String,Object>> actualOutParametersListFirst = process.execute(parametersFirst);
        
        Map<String,Object> parametersSecond = actualOutParametersListFirst[0].clone(); //-- Terminate hands back one
        
        List<Map<String,Object>> actualOutParametersListSecond = process.execute(parametersSecond);
        
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