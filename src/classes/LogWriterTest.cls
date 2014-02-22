@isTest
private class LogWriterTest{

            private static testMethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessNotificationId() {
        //arrange
        String chainName  = 'LogWriterChain';
        Integer theSequence =  1;
        Id theId  = '000000000000000AAA';
        Process__c logWriterProcess = Processes.generateOne(LogWriter.class);
        
        Chain__c chain = new Chain__c(Name = chainName);
        insert chain;
    
        Map<String,Object> parameters = new Map<String,Object>{
            // 'eda__notificationId' => '1234567abcde',  // null notification Id
            'id' => theId
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            LogWriter plugin = new LogWriter();
            Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
            List<Map<String,Object>> results = Utility.convert(result);
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
      
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException);
        
        String expectedMessage = 'Unable to access the notification id';
        System.assert( actualMessage.contains(expectedMessage) );
    }
    
	private static testMethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessChainStep() {
        //arrange
        String chainName  = 'LogWriterChain';
        Integer theSequence =  1;
        Id theId  = '000000000000000AAA';
        Process__c logWriterProcess = Processes.generateOne(LogWriter.class);
        
        Chain__c chain = new Chain__c(Name = chainName);
        insert chain;
    
        Map<String,Object> parameters = new Map<String,Object>{
            'eda__notificationId' => '1234567abcde',
            'id' => theId
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            LogWriter plugin = new LogWriter();
            Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
            List<Map<String,Object>> results = Utility.convert(result);
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
      
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException);
        
        String expectedMessage = 'Unable to access the Chain Step';
        System.assert( actualMessage.contains(expectedMessage) );
    }
    

    private static testMethod void callingInvokeInsertsExpectedLogWriterEntries() {
        //arrange
        String theIdentifier1 = 'BALLS';
        String theIdentifier2 = 'CROW';
       
        String chainName  = 'LogChain';
        Integer sequenceA2 =  1;
        Id theId  = '000000000000000AAA';
        Process__c logWriterProcess = Processes.generateOne(LogWriter.class);
               
        Chain__c chain = new Chain__c(Name = chainName);
        insert chain;
        
        ChainStep__c chainStepA2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = sequenceA2, Process__c = logWriterProcess.Id);
        insert chainStepA2;
 
        LogConfiguration__c configuration1  = new LogConfiguration__c(
            GroupIdentifier__c = theIdentifier1
        );
        insert configuration1;
         
        LogConfiguration__c configuration2  = new LogConfiguration__c(
            GroupIdentifier__c = theIdentifier2
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
            'id' => theId,
            'eda__notificationId' => '1234567abcde',
            'eda__logGroupIds' => logGroupIds,
            'eda__chainName' => chainName,
            'eda__sequence' => sequenceA2
        };
        
        //act
        LogWriter plugin = new LogWriter();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = Utility.convert(result);
        
        //assemble
        List<LogWriterEntry__c> LogWriterEntries = [
            SELECT id, Name, ChainStep__c,  LogGroup__c, Parameters__c
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
        String actualChainName;
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
        String expectedChainName = chainName;
        System.assertEquals(expectedLogGroup1, actualLogGroup1);
        System.assertEquals(expectedLogGroup2, actualLogGroup2);
        System.assertEquals(expectedParameters, actualParameters);
        System.assertEquals(actualParametersSerialized1, actualParametersSerialized2);
        System.assert(actualParametersSerialized1.contains(expectedChainName));
    }
}