@isTest
private class LogWriterTest{
    
    private static testMethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessMessageGuid() {
        //arrange
        String sequenceName  = 'LogWriterSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA';
        Process__c logWriterProcess = Processes.generateOne(LogWriter.class);
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
    
        Map<String,Object> parameters = new Map<String,Object>{
            // 'eda_MessageGuid' => '1234567abcde',  // null message Guid
            'Id' => theId
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            LogWriter plugin = new LogWriter();
            Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
            List<Map<String,Object>> results = EdaUtility.convert(result);
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
      
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException);
        
        String expectedMessage = 'Unable to access the message Guid';
        System.assert( actualMessage.contains(expectedMessage) );
    }
    
	private static testMethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessStep() {
        //arrange
        String sequenceName  = 'LogWriterSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA';
        Process__c logWriterProcess = Processes.generateOne(LogWriter.class);
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
    
        Map<String,Object> parameters = new Map<String,Object>{
            'eda_MessageGuid' => '1234567abcde',
            'Id' => theId
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            LogWriter plugin = new LogWriter();
            Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
            List<Map<String,Object>> results = EdaUtility.convert(result);
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
      
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException);
        
        String expectedMessage = 'Unable to access the Step';
        System.assert( actualMessage.contains(expectedMessage) );
    }

    private static testMethod void callingInvokeInsertsExpectedLogWriterEntries() {
        //arrange
        String theIdentifier1 = 'BALLS';
        String theIdentifier2 = 'CROW';
       
        String sequenceName  = 'LogSequence';
        Integer positionA2 =  1;
        Id theId  = '000000000000000AAA';
        Process__c logWriterProcess = Processes.generateOne(LogWriter.class);
               
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c stepA2 = new Step__c(Sequence__c = sequence.Id, Position__c = positionA2, Process__c = logWriterProcess.Id);
        insert stepA2;
 
        LogConfiguration__c configuration1  = new LogConfiguration__c(
            StaticGroupIdentifier__c = theIdentifier1
        );
        insert configuration1;
         
        LogConfiguration__c configuration2  = new LogConfiguration__c(
            StaticGroupIdentifier__c = theIdentifier2
        );
        insert configuration2;
        
        LogGroup__c logGroup1  = new LogGroup__c(
            LogConfiguration__c = configuration1.Id,
            GroupIdentifier__c =  theIdentifier1,
            Stamp__c = System.Now()
        );
        insert logGroup1;
        
        LogGroup__c logGroup2  = new LogGroup__c(
            LogConfiguration__c = configuration2.Id,
            GroupIdentifier__c =  theIdentifier2,
            Stamp__c = System.Now()
        );
        insert logGroup2;
 
        List<Object> logGroupIds = new List<Object>{ logGroup1.Id, logGroup2.Id };
 
        Map<String,Object> parameters = new Map<String,Object>{
            'Id' => theId,
            'eda_MessageGuid' => '1234567abcde',
            'eda_LogGroupIds' => logGroupIds,
            'eda_SequenceName' => sequenceName,
            'eda_Position' => positionA2
        };
        
        //act
        LogWriter plugin = new LogWriter();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = EdaUtility.convert(result);
        
        //assemble
        List<LogWriterEntry__c> logWriterEntries = [
            SELECT id, Name, Step__c,  LogGroup__c, Parameters__c
            FROM LogWriterEntry__c
        ];
        
         
        Boolean actualLogGroup1 = false;
        Boolean actualLogGroup2 = false;
        String actualParametersSerialized1;
        String actualParametersSerialized2;
        for (LogWriterEntry__c  logWriterEntry : logWriterEntries) {
            if (logWriterEntry.LogGroup__c == logGroup1.Id) {
            	actualLogGroup1 = true;
                actualParametersSerialized1 = logWriterEntry.Parameters__c;
            }
            if (logWriterEntry.LogGroup__c == logGroup2.Id) {
            	actualLogGroup2 = true;
                actualParametersSerialized2 = logWriterEntry.Parameters__c;
            }
        }
        String actualSequenceName;
        Boolean actualParameters = ( actualParametersSerialized2 != null);
 
        
            
        // Assert
        Integer expectedResultsSize = 1;
        Integer actualResultsSize = results.size();
        System.assertEquals(expectedResultsSize, actualResultsSize);
        
        Integer expectedLogWriterEntrySize = 2;
        Integer actualLogWriterEntrySize = LogWriterEntries.size();
        System.assertEquals(expectedLogWriterEntrySize, actualLogWriterEntrySize);

        Boolean expectedLogGroup1 = true;
        Boolean expectedLogGroup2 = true;
        Boolean expectedParameters = true;
        String expectedSequenceName = sequenceName;
        System.assertEquals(expectedLogGroup1, actualLogGroup1);
        System.assertEquals(expectedLogGroup2, actualLogGroup2);
        System.assertEquals(expectedParameters, actualParameters);
        System.assertEquals(actualParametersSerialized1, actualParametersSerialized2);
        System.assert(actualParametersSerialized1.contains(expectedSequenceName));
    }

}