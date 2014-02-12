@isTest
private class LogInitializerTest {

        private static testMethod void canDetermineConfigurable () {
        //arrange processes
        Process__c logInitializerProcess = Processes.generateOne(LogInitializer.class);
        
        //act
        String actualConfiguration = logInitializerProcess.Configurable__c;
        
        // Assert
        String expectedConfiguration = Schema.SobjectType.LogConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration); 
    }
    
    private static testMethod void callingInvokeInsertsExpectedCompositeIdentifiersOnLogGroupForConfigIdentifierEqNull() {
        //arrange
        String chainName  = 'LogInitializerChain';
        Integer theSequence =  1;
        Id theId  = '000000000000000AAA';
        Process__c logInitializerProcess = Processes.generateOne(LogInitializer.class);
        
        Chain__c chain = new Chain__c(Name = chainName);
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = theSequence, Process__c = logInitializerProcess.Id);
        insert chainStep;
        
        LogConfiguration__c configuration = [
            SELECT Id, GroupIdentifier__c 
            FROM LogConfiguration__c
        ];
        configuration.GroupIdentifier__c = null; // no identifier specified
        update configuration;
        
        Map<String,Object> notification = new Map<String,Object>{
            'id' => theId,
            'eda__configuration' =>  configuration.Id,  
            'eda__chainName' => chainName,
            'eda__sequence' => theSequence
        };
        
        //act
        LogInitializer plugin = new LogInitializer();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> results = Utility.convert(result);
        
        //assemble
        DateTime expectedStampTo = System.Now().addSeconds(1);
        DateTime expectedStampFrom = System.Now().addSeconds(-1);
        List<LogGroup__c> logGroups = [ 
            SELECT id, Name, LogConfiguration__c,  GroupIdentifier__c, Stamp__c
            FROM LogGroup__c
            WHERE Stamp__c >= :expectedStampFrom
            AND Stamp__c <=  :expectedStampTo
        ];

        String  actualGroupIdentifier = null;
        Integer actualLogGroupSize = logGroups.size();
        if (actualLogGroupSize > 0) {
             actualGroupIdentifier =  logGroups[0].GroupIdentifier__c;
        }
        
           
        // Assert
        Integer expectedResultsSize = 1;
        Integer actualResultsSize = results.size(); 
        System.assertEquals(expectedResultsSize, actualResultsSize); 
        
        Integer expectedLogGroupSize = 1;
        System.assertEquals(expectedLogGroupSize, actualLogGroupSize); 
        
        String expectedGroupIdentifier1 = chainName ;
        String expectedGroupIdentifier2 = String.valueOf(theSequence) ;
        System.assert(actualGroupIdentifier.contains(expectedGroupIdentifier1));
        System.assert(actualGroupIdentifier.contains(expectedGroupIdentifier2));      
    }
    
    
    private static testMethod void callingInvokeInsertsExpectedCompositeIdentifiersOnLogGroupForConfigIdentifierNotNull() {
        //arrange
        String theIdentifier  = 'BALLS-SAID';
        String chainName  = 'LogInitializerChain';
        Integer theSequence =  1;
        Id theId  = '000000000000000AAA';
        Process__c logInitializerProcess = Processes.generateOne(LogInitializer.class);
        
        Chain__c chain = new Chain__c(Name = chainName);
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = theSequence, Process__c = logInitializerProcess.Id);
        insert chainStep;
        
        LogConfiguration__c configuration = [
            SELECT Id, GroupIdentifier__c 
            FROM LogConfiguration__c
        ];
        configuration.GroupIdentifier__c = theIdentifier; // not null
        update configuration;
        
        Map<String,Object> notification = new Map<String,Object>{
            'id' => theId,
            'eda__configuration' =>  configuration.Id,  
            'eda__chainName' => chainName,
            'eda__sequence' => theSequence
        };
        
        //act
        LogInitializer plugin = new LogInitializer();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> results = Utility.convert(result);
        
        //assemble
        DateTime expectedStampTo = System.Now().addSeconds(1);
        DateTime expectedStampFrom = System.Now().addSeconds(-1);
        List<LogGroup__c> logGroups = [ 
            SELECT id, Name, LogConfiguration__c,  GroupIdentifier__c, Stamp__c
            FROM LogGroup__c
            WHERE Stamp__c >= :expectedStampFrom
            AND Stamp__c <=  :expectedStampTo
        ];

        String  actualGroupIdentifier = null;
        Integer actualLogGroupSize = logGroups.size();
        if (actualLogGroupSize > 0) {
             actualGroupIdentifier =  logGroups[0].GroupIdentifier__c;
        }
        
           
        // Assert
        Integer expectedResultsSize = 1;
        Integer actualResultsSize = results.size(); 
        System.assertEquals(expectedResultsSize, actualResultsSize); 
        
        Integer expectedLogGroupSize = 1;
        System.assertEquals(expectedLogGroupSize, actualLogGroupSize); 
        
        String expectedGroupIdentifier1 = theIdentifier ;
        System.assert(actualGroupIdentifier.contains(expectedGroupIdentifier1));     
    }

    
    private static testMethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessChainStep() {
        //arrange
        String chainName  = 'LogInitializerChain';
        Integer theSequence =  1;
        Id theId  = '000000000000000AAA';
        Process__c logInitializerProcess = Processes.generateOne(LogInitializer.class);
        
        Chain__c chain = new Chain__c(Name = chainName);
        insert chain;
    
        Map<String,Object> notification = new Map<String,Object>{
            'id' => theId 
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            LogInitializer plugin = new LogInitializer();
            Process.PluginResult result = plugin.invoke(new Process.PluginRequest(notification));
            List<Map<String,Object>> results = Utility.convert(result);
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
      
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException); 
        
        String expectedMessage = 'Unable to access the Chain Step Sequence and Chain Name';
        System.assert( actualMessage.contains(expectedMessage) );    
    }

     
        
    private static testMethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessConfig() {
        //arrange
        String chainName  = 'LogInitializerChain';
        Integer theSequence =  1;
        Id theId  = '000000000000000AAA';
        Process__c logInitializerProcess = Processes.generateOne(LogInitializer.class);
        
        Chain__c chain = new Chain__c(Name = chainName);
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = logInitializerProcess.Id);
        insert chainStep;
        
        LogConfiguration__c configuration = [
            SELECT Id, GroupIdentifier__c 
            FROM LogConfiguration__c
        ];
        delete configuration;
        
        Map<String,Object> notification = new Map<String,Object>{
           'id' => theId   ,
           'eda__configuration' =>  configuration.Id,  
           'eda__chainName' => chainName,
           'eda__sequence' => theSequence
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            LogInitializer plugin = new LogInitializer();
            Process.PluginResult result = plugin.invoke(new Process.PluginRequest(notification));
            List<Map<String,Object>> results = Utility.convert(result);
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
 
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException); 
        
        String expectedMessage = 'Unable to access Log Configuration';
        System.assert( actualMessage.contains(expectedMessage) );    
    }
    
    
    private static testMethod void callingGetHydratedThrowsExpectedExceptionWhenIdInvalid() {
        //arrange
        Id bullshitId = '000000000000000AAA';  

        //act
        String actualMessage;
        Boolean actualExceptionFlag  = false;
        try {
            SObject o = LogInitializer.getHydrated(bullshitId);
        } catch (Exception e ) {
            actualMessage = e.getMessage();
            actualExceptionFlag  = true;
        }
  
        // assert
        Boolean expectedExceptionFlag  = true;
        String expectedMessage = 'Cannot hydate SObject';  
        System.assertEquals( actualExceptionFlag, expectedExceptionFlag ); 
        System.assert( actualMessage.contains(expectedMessage) );   
    }                      
                            
    private static testMethod void callingGetHydratedReturnsFullyHydratedSObject() {
        //arrange
        String theName = 'BALLS';
        String theJigSaw = '12345';
        Account account = new Account(Name = theName, JigSaw = theJigSaw);
        insert account;
        Id theId = account.Id;

        //act
        SObject o = LogInitializer.getHydrated(theId);
 
        // assemble
        String actualMessage  = json.serialize(o);
        
        // assert
        String expectedMessage1 = theName;
        String expectedMessage2 = theJigSaw;        
        System.assert( actualMessage.contains(expectedMessage1) );   
        System.assert( actualMessage.contains(expectedMessage2) );    
    }

    
   private static testMethod void callingGetIdentiferReturnsExpectedIdentifier() {
        //arrange
        String theName = 'BALLS';
        String theJigsaw = '12345';
        SObject so = new Account(Name = theName, Jigsaw = theJigsaw);
        String fieldName = 'Jigsaw';

        //act
        String actualIdentifier = LogInitializer.getIdentifer(fieldName ,so);
      
        // assert
        String expectedIdentifier = theJigSaw; 
        System.assertEquals(expectedIdentifier, actualIdentifier); 
    }
}