@isTest //-- no view of org data
private class SinkTest
{

    static testMethod void callingExecuteReturnsExpectedNotificationCollectionWhenBoomerangAttribsDefinedOnNotification()
    {
        // Arrange :
        String chainName = 'the-chain';
        Decimal sequence = 1;
        String data = 'data';
        String boomerangChainName = 'boomerang-chain';
        Decimal boomerangSequence = 2;

        Chain__c chain = new Chain__c(Name = boomerangChainName);
        insert chain;
        
        Process__c process = new Process__c(Name = 'Boomerang');
        insert process;
        
        ChainStep__c chainStep = new ChainStep__c ( Chain__c = chain.Id, Process__c = process.Id, Sequence__c = boomerangSequence);
        insert chainStep;

        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => sequence,
            'eda__boomerangChainStepIds' => new List<Id>{chainStep.Id},
            'data' => data
        };


        Decimal expectedSize = 1;
        String expectedChainName = boomerangChainName;
        Decimal expectedSequence = boomerangSequence;

        // Act
        Sink sink = new Sink();
        Process.PluginResult results = sink.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> actualOutNotifications = Utility.convert(results);

        // prepare
        Decimal actualSize = actualOutNotifications.size();
        String actualChainName = null;
        Decimal actualSequence = null;
        if (actualSize > 0) {
            Map<String,Object> actualNotification = actualOutNotifications[0];
            actualChainName = (String)actualNotification.get('eda__chainName');
            actualSequence = (Decimal)actualNotification.get('eda__sequence');
        }

        // Assert
        System.assertEquals(expectedSize, actualSize);
        System.assertEquals(expectedChainName, actualChainName);
        System.assertEquals(expectedSequence, actualSequence);
    }
    
    static testMethod void 
    callingExecuteReturnsExpectedNotificationCollectionWhenNoBoomerangAttribsDefinedOnNotification() {
        // Arrange :
        String chainName = 'the-chain';
        Decimal sequence = 1;
        String data = 'data';
 
 

        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => sequence,
            'data' => data
        };

        Decimal expectedSize = 0;
 
        // Act
        Sink sink = new Sink();
        Process.PluginResult results = sink.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> actualOutNotifications = Utility.convert(results);

        // prepare
        Decimal actualSize = actualOutNotifications.size();
 
        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
    
    static testMethod void testMultipleBoomerangsGetPoppedOffStack() {
        // Arrange :
        String chainName = 'the-chain';
        Decimal sequence = 1;
        String data = 'data';
        String boomerangChainName = 'boomerang-chain';
        Decimal boomerangSequence  = 2;

        Chain__c chain = new Chain__c(Name = boomerangChainName);
        insert chain;
        
        Process__c process = new Process__c(Name = 'Boomerang');
        insert process;
        
        ChainStep__c chainStep01 = new ChainStep__c ( Chain__c = chain.Id, Process__c = process.Id, Sequence__c = boomerangSequence);
        insert chainStep01;
        ChainStep__c chainStep02 = new ChainStep__c ( Chain__c = chain.Id, Process__c = process.Id, Sequence__c = boomerangSequence);
        insert chainStep02;

        Id boomerangChainStepId01 = chainStep01.Id ;
        Id boomerangChainStepId02 = chainStep02.Id ; 
        List<Id> boomerangChainStepIds = new List<Id>();
        boomerangChainStepIds.add(boomerangChainStepId01);
        boomerangChainStepIds.add(boomerangChainStepId02);
        
        Map<String,Object> notificationFirst = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => sequence,
            'eda__boomerangChainStepIds' => boomerangChainStepIds,
            'data' => data
        };


        // Act
        Sink sink = new Sink();
        
        Process.PluginResult resultsInvokeFirst = sink.invoke(new Process.PluginRequest(notificationFirst));
        List<Map<String,Object>> actualOutNotificationsFirst = Utility.convert(resultsInvokeFirst);
        
        Map<String,Object> notificationSecond = actualOutNotificationsFirst[0].clone(); //-- Sink hands back one
        
        Process.PluginResult resultsInvokeSecond = sink.invoke(new Process.PluginRequest(notificationSecond));
        List<Map<String,Object>> actualOutNotificationsSecond = Utility.convert(resultsInvokeSecond);
        
        // prepare
        List<Object> actualChainStepIdsAfterFirst = (List<Object>)actualOutNotificationsFirst[0].get('eda__boomerangChainStepIds'); 
        List<Object> actualChainStepIdsAfterSecond = (List<Object>)actualOutNotificationsSecond[0].get('eda__boomerangChainStepIds');
        
        Integer actualSizeAfterFirst = actualChainStepIdsAfterFirst.size();
        Integer actualSizeAfterSecond = actualChainStepIdsAfterSecond.size();
        
        Integer expectedSizeAfterFirst = 1;
        Integer expectedSizeAfterSecond = 0;
        
        // Assert
        System.assertEquals(expectedSizeAfterFirst, actualSizeAfterFirst);
        System.assertEquals(expectedSizeAfterSecond , actualSizeAfterSecond);
    }
    
    static testMethod void callingGetHeathReturnsExpectedList() {
        // #11 : Trivial error / health checker
        // * Chain with no sink (error)
        // * Chain with more than one Sink (error)
        // * Sink that's not at the end (error)
        
        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;    
        Chain__c chainC = new Chain__c(Name = 'ChainC');
        insert chainC;    
        Chain__c chainD = new Chain__c(Name = 'ChainD');
        insert chainD;    
        
        Process__c sinkProcess  = new Process__c(Name = 'Sink');
        insert sinkProcess;
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       
        
        // Chain A - Ok
        ChainStep__c chainStepA1 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c  = 1);
        ChainStep__c chainStepA2 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = sinkProcess.Id, Sequence__c = 2);   
        
        // Chain B - Problem : Sink Not last Step
        ChainStep__c chainStepB1 =  new ChainStep__C(Chain__c = chainB.Id, Process__c = sinkProcess.Id, Sequence__c = 1);
        ChainStep__c chainStepB2 =  new ChainStep__C(Chain__c = chainB.Id, Process__c = wireTapProcess.Id, Sequence__c = 2);       
 
        // Chain C - Problem : More than One Sink
        ChainStep__c chainStepC1 =  new ChainStep__C(Chain__c = chainC.Id, Process__c = sinkProcess.Id, Sequence__c = 1);
        ChainStep__c chainStepC2 =  new ChainStep__C(Chain__c = chainC.Id, Process__c = sinkProcess.Id, Sequence__c = 2); 
        
        // Chain D - Problem : Zero Sinks
        ChainStep__c chainStepD1 =  new ChainStep__C(Chain__c = chainD.Id, Process__c = wireTapProcess.Id, Sequence__c = 1);
        ChainStep__c chainStepD2 =  new ChainStep__C(Chain__c = chainD.Id, Process__c = wireTapProcess.Id, Sequence__c = 2); 
        insert new List<ChainStep__c>{
                chainStepA1, 
                chainStepA2, 
                chainStepB1, 
                chainStepB2, 
                chainStepC1, 
                chainStepC2, 
                chainStepD1, 
                chainStepD2};

        // Act :
        List<HealthController.Health> sinkHealths =  Sink.getHealth(); 
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualOkCount = 0;
        Integer actualErrorCount = 0;
        for (HealthController.Health sinkHealth : sinkHealths ) {
            chainIdToDescription.put(sinkHealth.ChainId, sinkHealth.Detail);
            if (sinkHealth.Status == 'Ok') {
                actualOkCount++;   
            }
            if (sinkHealth.Status == 'Error') {
                actualErrorCount++;   
            }         
        }
        
        // Assert :
        Integer expectedCount = 4;
        Integer actualCount = sinkHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedOkCount = 1;
        System.assertEquals(expectedOkCount, actualOkCount);
        
        Integer expectedErrorCount = 3;
        System.assertEquals(expectedErrorCount, actualErrorCount);
        
        String actualChainSinkNotLastStep = chainIdToDescription.get(chainB.Id);
        String expectedChainSinkNotLastStep = 'Sink process not present at end of chain';
        System.assertEquals(expectedChainSinkNotLastStep, actualChainSinkNotLastStep);
        
        String actualChainMoreThanOneSink = chainIdToDescription.get(chainC.Id);
        String expectedChainMoreThanOneSink ='More than one sink found in chain';
        System.assertEquals(expectedChainMoreThanOneSink, actualChainMoreThanOneSink);
        
        String actualChainZeroSinks = chainIdToDescription.get(chainD.Id);
        String  expectedChainZeroSinks =  'No Sink found in chain';
        System.assertEquals(expectedChainZeroSinks, actualChainZeroSinks);          
    }

    
    static testMethod void callingGetHeathReturnsExpectedListWhenSinkNotDefined() {
        
        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
 
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       
        
        // Chain A - Error but Sink process not defined
        ChainStep__c chainStepA1 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c  = 1);
        ChainStep__c chainStepA2 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c = 2);   

        // Act :
        List<HealthController.Health> sinkHealths =  Sink.getHealth();
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualOkCount = 0;
        Integer actualUnknownCount = 0;
        for (HealthController.Health sinkHealth : sinkHealths ) {
            chainIdToDescription.put(sinkHealth.ChainId, sinkHealth.Detail);
            if (sinkHealth.Status == 'Ok') {
                actualOkCount++;   
            }
            if (sinkHealth.Status == 'Unknown') {
                actualUnknownCount++;   
            }         
        }
        
        // Assert :
        Integer expectedCount = 1;
        Integer actualCount = sinkHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedOkCount = 0;
        System.assertEquals(expectedOkCount, actualOkCount);
        
        Integer expectedUnknownCount = 1;
        System.assertEquals(expectedUnknownCount, actualUnknownCount);
        
        String actualUnknown = chainIdToDescription.get(chainA.Id);
        String expectedUnknown = 'Cannot resolve Id of Sink process';
        System.assertEquals(expectedUnknown, actualUnknown);
    } 
}