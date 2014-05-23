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
        Step__c step1 = StepObjectSet.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c step2 = StepObjectSet.generateOne(sequence.Id, subsequenceProcess.Id);

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_SequenceName' => sequenceName,
            'eda_Position' => position,
            'eda_SubsequenceStepIds' => new List<Id>{step2.Id},
            'data' => data
        };


        Decimal expectedSize = 1;
        String expectedSequenceName = subsequenceName;
        Decimal expectedPosition = subsequencePosition;

        // Act
        Terminate plugin = new Terminate();
        Process.PluginResult results = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualOutParametersList = EdaUtility.convert(results);

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        String actualSequenceName = null;
        Decimal actualPosition = null;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualSequenceName = (String)actualParameters.get('eda_SequenceName');
            actualPosition = (Decimal)actualParameters.get('eda_Position');
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
            'eda_SequenceName' => sequenceName,
            'eda_Position' => position,
            'data' => data
        };

        Decimal expectedSize = 0;
 
        // Act
        Terminate plugin = new Terminate();
        Process.PluginResult results = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualOutParametersList = EdaUtility.convert(results);

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
        
        Step__c step01 = StepObjectSet.generateOne(sequence.Id, subsequenceProcess.Id);
        Step__c step02 = StepObjectSet.generateOne(sequence.Id, subsequenceProcess.Id);
        
        Id subsequenceStepId01 = step01.Id ;
        Id subsequenceStepId02 = step02.Id ;
        List<Id> subsequenceStepIds = new List<Id>();
        subsequenceStepIds.add(subsequenceStepId01);
        subsequenceStepIds.add(subsequenceStepId02);
        
        Map<String,Object> parametersFirst = new Map<String,Object> {
            'eda_SequenceName' => sequenceName,
            'eda_Position' => position,
            'eda_SubsequenceStepIds' => subsequenceStepIds,
            'data' => data
        };


        // Act
        Terminate plugin = new Terminate();
        
        Process.PluginResult resultsInvokeFirst = plugin.invoke(new Process.PluginRequest(parametersFirst));
        List<Map<String,Object>> actualOutParametersListFirst = EdaUtility.convert(resultsInvokeFirst);
        
        Map<String,Object> parametersSecond = actualOutParametersListFirst[0].clone(); //-- Terminate hands back one
        
        Process.PluginResult resultsInvokeSecond = plugin.invoke(new Process.PluginRequest(parametersSecond));
        List<Map<String,Object>> actualOutParametersListSecond = EdaUtility.convert(resultsInvokeSecond);
        
        // prepare
        List<Object> actualStepIdsAfterFirst = (List<Object>)actualOutParametersListFirst[0].get('eda_SubsequenceStepIds');
        List<Object> actualStepIdsAfterSecond = (List<Object>)actualOutParametersListSecond[0].get('eda_SubsequenceStepIds');
        
        Integer actualSizeAfterFirst = actualStepIdsAfterFirst.size();
        Integer actualSizeAfterSecond = actualStepIdsAfterSecond.size();
        
        Integer expectedSizeAfterFirst = 1;
        Integer expectedSizeAfterSecond = 0;
        
        // Assert
        System.assertEquals(expectedSizeAfterFirst, actualSizeAfterFirst);
        System.assertEquals(expectedSizeAfterSecond , actualSizeAfterSecond);
    }

}