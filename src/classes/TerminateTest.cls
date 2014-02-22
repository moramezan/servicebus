@isTest //-- no view of org data
private class TerminateTest
{

    static testMethod void callingExecuteReturnsExpectedParametersCollectionWhenBoomerangAttribsDefinedOnParameters()
    {
        // Arrange :
        String chainName = 'the-chain';
        Decimal sequence = 1;
        String data = 'data';
        String boomerangChainName = 'boomerang-chain';
        Decimal boomerangSequence = 2;
        
        //arrange processes
        Process__c boomerangProcess = Processes.generateOne(Boomerang.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = boomerangChainName);
        insert chain;
        
        //arrange steps
        ChainStep__c chainStep1 = ChainSteps.generateOne(chain.Id, wiretapProcess.Id);
        ChainStep__c chainStep2 = ChainSteps.generateOne(chain.Id, boomerangProcess.Id);

        Map<String,Object> parameters = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => sequence,
            'eda__boomerangChainStepIds' => new List<Id>{chainStep2.Id},
            'data' => data
        };


        Decimal expectedSize = 1;
        String expectedChainName = boomerangChainName;
        Decimal expectedSequence = boomerangSequence;

        // Act
        Terminate terminate = new Terminate();
        Process.PluginResult results = terminate.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualOutParametersList = Utility.convert(results);

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        String actualChainName = null;
        Decimal actualSequence = null;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualChainName = (String)actualParameters.get('eda__chainName');
            actualSequence = (Decimal)actualParameters.get('eda__sequence');
        }

        // Assert
        System.assertEquals(expectedSize, actualSize);
        System.assertEquals(expectedChainName, actualChainName);
        System.assertEquals(expectedSequence, actualSequence);
    }
    
    static testMethod void
    callingExecuteReturnsExpectedParametersCollectionWhenNoBoomerangAttribsDefinedOnParameters() {
        // Arrange :
        String chainName = 'the-chain';
        Decimal sequence = 1;
        String data = 'data';
 
 

        Map<String,Object> parameters = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => sequence,
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
        String chainName = 'the-chain';
        Decimal sequence = 1;
        String data = 'data';
        String boomerangChainName = 'boomerang-chain';
        Decimal boomerangSequence  = 2;

        Chain__c chain = new Chain__c(Name = boomerangChainName);
        insert chain;
        
        Process__c process = Processes.generateOne(Boomerang.class);
        
        ChainStep__c chainStep01 = ChainSteps.generateOne(chain.Id, process.Id);
        ChainStep__c chainStep02 = ChainSteps.generateOne(chain.Id, process.Id);
        
        Id boomerangChainStepId01 = chainStep01.Id ;
        Id boomerangChainStepId02 = chainStep02.Id ;
        List<Id> boomerangChainStepIds = new List<Id>();
        boomerangChainStepIds.add(boomerangChainStepId01);
        boomerangChainStepIds.add(boomerangChainStepId02);
        
        Map<String,Object> parametersFirst = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => sequence,
            'eda__boomerangChainStepIds' => boomerangChainStepIds,
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
        List<Object> actualChainStepIdsAfterFirst = (List<Object>)actualOutParametersListFirst[0].get('eda__boomerangChainStepIds');
        List<Object> actualChainStepIdsAfterSecond = (List<Object>)actualOutParametersListSecond[0].get('eda__boomerangChainStepIds');
        
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
        // * Chain with no Terminate (error)
        // * Chain with more than one Terminate (error)
        // * Terminate that's not at the end (error)
        
        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;
        Chain__c chainC = new Chain__c(Name = 'ChainC');
        insert chainC;
        Chain__c chainD = new Chain__c(Name = 'ChainD');
        insert chainD;
        
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        
        // Chain A - Ok
        ChainStep__c chainStepA1 = ChainSteps.generateOne(chainA.Id, wireTapProcess.Id);
        ChainStep__c chainStepA2 = ChainSteps.generateOne(chainA.Id, terminateProcess.Id);
        
        // Chain B - Problem : Terminate Not last Step
        ChainStep__c chainStepB1 = ChainSteps.generateOne(chainB.Id, terminateProcess.Id);
        ChainStep__c chainStepB2 = ChainSteps.generateOne(chainB.Id, wireTapProcess.Id);
 
        // Chain C - Problem : More than One Terminate
        ChainStep__c chainStepC1 = ChainSteps.generateOne(chainC.Id, terminateProcess.Id);
        ChainStep__c chainStepC2 = ChainSteps.generateOne(chainC.Id, terminateProcess.Id);
        
        // Chain D - Problem : Zero Terminate
        ChainStep__c chainStepD1 = ChainSteps.generateOne(chainD.Id, wireTapProcess.Id);
        ChainStep__c chainStepD2 = ChainSteps.generateOne(chainD.Id, wireTapProcess.Id);

        // Act :
        List<HealthController.Health> terminateHealths =  Terminate.getHealth();
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualOkCount = 0;
        Integer actualErrorCount = 0;
        for (HealthController.Health terminateHealth : terminateHealths ) {
            chainIdToDescription.put(terminateHealth.ChainId, terminateHealth.Detail);
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
        
        String actualChainTerminateNotLastStep = chainIdToDescription.get(chainB.Id);
        String expectedChainTerminateNotLastStep = 'Terminate process not present at end of chain';
        System.assertEquals(expectedChainTerminateNotLastStep, actualChainTerminateNotLastStep);
        
        String actualChainMoreThanOneTerminate = chainIdToDescription.get(chainC.Id);
        String expectedChainMoreThanOneTerminate ='More than one Terminate found in chain';
        System.assertEquals(expectedChainMoreThanOneTerminate, actualChainMoreThanOneTerminate);
        
        String actualChainZeroTerminates = chainIdToDescription.get(chainD.Id);
        String  expectedChainZeroTerminates =  'No Terminate found in chain';
        System.assertEquals(expectedChainZeroTerminates, actualChainZeroTerminates);
    }

    
    static testMethod void callingGetHeathReturnsExpectedListWhenTerminateNotDefined() {
        
        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
 
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;
        
        // Chain A - Error but Terminate process not defined
        ChainStep__c chainStepA1 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c  = 1);
        ChainStep__c chainStepA2 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c = 2);

        // Act :
        List<HealthController.Health> terminateHealths =  Terminate.getHealth();
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>();
        Integer actualOkCount = 0;
        Integer actualUnknownCount = 0;
        for (HealthController.Health terminateHealth : terminateHealths ) {
            chainIdToDescription.put(terminateHealth.ChainId, terminateHealth.Detail);
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
        
        String actualUnknown = chainIdToDescription.get(chainA.Id);
        String expectedUnknown = 'Cannot resolve Id of Terminate process';
        System.assertEquals(expectedUnknown, actualUnknown);
    }
}