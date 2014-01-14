@isTest public class SubscribeTest{
    static testMethod void testDescribe() {
        // Arrange 
        Subscribe process = new Subscribe();
        String className = String.valueOf(process).split(':')[0]; 
        Map<string, Object> meta = Utility.meta(className);  
            
        // Act 
        String actualDescription = (String) meta.get('configurable');
        
        // Assert
        String expectedDescription = Schema.SobjectType.SubscribeConfiguration__c.Name;
        System.assertEquals(expectedDescription, actualDescription);
        
    }
    
    static testMethod void testSubscribeProcessActsAsNoop() {
        //arrange
        String data = '{"herp":"derp"}';
        Map<String,Object> notification = (Map<String,Object>)System.Json.deserializeUntyped(data);
        Subscribe process = new Subscribe();
        
        //act
        Process.PluginResult result = process.invoke(new Process.PluginRequest(notification));
        
        //assert
        List<Map<string, object>> notifications = Utility.convert(result);
        
        integer expectedSize = 1;
        integer actualSize = notifications.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = data;
        string actualData = system.json.serialize( notifications [0] );
        System.assertEquals(expectedData, actualData);  
    }

      static testMethod void callingGetHealthReturnsExpectedListContaingStausEqUnknown() {

        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;
 
        // Processes :: Subscribe process not defined
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       
        
        // Chain A  
        ChainStep__c chainStepA1 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c  = 1);
        ChainStep__c chainStepA2 =  new ChainStep__C(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c = 2);   

        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth();
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualUnknownCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Unknown') {
                actualUnknownCount++;   
            }         
        }
        
        // Assert :
        Integer expectedCount = 1;
        Integer actualCount = SubscribeHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedUnknownCount = 1;
        System.assertEquals(expectedUnknownCount, actualUnknownCount);
        
        String actualUnknown = chainIdToDescription.get(chainA.Id);
        String expectedUnknown = 'Cannot resolve Id of Subscribe process';
        System.assertEquals(expectedUnknown, actualUnknown);
    }

    
  
    static testMethod void callingGetHealthReturnsExpectedListContaningStatusEqOk() {


        // Arrange :
        Chain__c chainPublish = new Chain__c(Name = 'Publish');
        insert chainPublish;
        Chain__c chainZ = new Chain__c(Name = 'ChainZ');
        insert chainZ;
  
        
        Process__c SubscribeProcess  = new Process__c(Name = 'Subscribe');
        insert SubscribeProcess;
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       
        Process__c publishProcess  = new Process__c(Name = 'Publish');
        insert publishProcess;
        
        // Chain Z - OK : Event is published
        ChainStep__c chainStepZ1 =  new ChainStep__c(Chain__c = chainZ.Id, Process__c = SubscribeProcess.Id, Sequence__c = 1); 
        ChainStep__c chainStepZ2 =  new ChainStep__c(Chain__c = chainZ.Id, Process__c = wireTapProcess.Id, Sequence__c  = 2);
        insert new List<ChainStep__c>{chainStepZ1, chainStepZ2};
        ChainStep__c chainStepZ3 =  new ChainStep__c(Chain__c = chainPublish.Id, Process__c = publishProcess.Id, Sequence__c = 1); 
        insert new List<ChainStep__c>{chainStepZ3};           
     
  
        // Event
        Event__c eventPublished = new Event__c(Name = 'an-event-that-IS-published');
        insert eventPublished;
        

        // Config Publish 
        Id publishConfigurationIdZ3 = (Id) [SELECT Id, Configuration__c 
                                     FROM ChainStep__c 
                                     WHERE Id = :chainStepZ3.Id LIMIT 1].Configuration__c;
        PublishConfiguration__c  publishConfigurationZ3 =  [SELECT Id, Event__c 
                                                              FROM PublishConfiguration__c 
                                                              WHERE Id = :publishConfigurationIdZ3];
        publishConfigurationZ3.Event__c = eventPublished.Id;
        update publishConfigurationZ3;    
        
        // Config Z1 
        Id configurationIdZ1 = (Id) [SELECT Id, Configuration__c 
                                     FROM ChainStep__c 
                                     WHERE Id = :chainStepZ1.Id LIMIT 1].Configuration__c;
        SubscribeConfiguration__c  subscribeConfigurationZ1 =  [SELECT Id, Event__c 
                                                              FROM SubscribeConfiguration__c 
                                                              WHERE Id = :configurationIdZ1];
        subscribeConfigurationZ1.Event__c = eventPublished.Id;
        update subscribeConfigurationZ1;
        
  
        
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualOkCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Ok') {
                actualOkCount++;   
            }
        }
        
        // Assert :
        Integer expectedCount = 1 + 1; // <Subscribe> + <Publish=1>
        Integer actualCount = SubscribeHealths.size();
        System.assertEquals(expectedCount, actualCount);

        Integer expectedOkCount = 1 + 1; // <Ok,Subscribe> + <Ok,Publish=1>
        System.assertEquals(expectedOkCount, actualOkCount);
    }
    
    
    static testMethod void callingGetHealthReturnsExpectedListContaningStatusEqWarning() {


        // Arrange :
        Chain__c chainA = new Chain__c(Name = 'ChainA');
        insert chainA;

        
        Process__c SubscribeProcess  = new Process__c(Name = 'Subscribe');
        insert SubscribeProcess;
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       


        // Chain A - Warning : Ok but event Not published
        ChainStep__c chainStepA1 =  new ChainStep__c(Chain__c = chainA.Id, Process__c = SubscribeProcess.Id, Sequence__c = 1); 
        ChainStep__c chainStepA2 =  new ChainStep__c(Chain__c = chainA.Id, Process__c = wireTapProcess.Id, Sequence__c  = 2);
        insert new List<ChainStep__c>{chainStepA1, chainStepA2};

        // Event
        Event__c eventNotPublished = new Event__c(Name = 'an-event-not-published');
        insert eventNotPublished;

        
       
        // Config A1
        Id configurationIdA1 = (Id) [SELECT Id, Configuration__c 
                                     FROM ChainStep__c 
                                     WHERE Id = :chainStepA1.Id LIMIT 1].Configuration__c;
        SubscribeConfiguration__c  subscribeConfigurationA1 =  [SELECT Id, Event__c 
                                                              FROM SubscribeConfiguration__c 
                                                              WHERE Id = :configurationIdA1];
        subscribeConfigurationA1.Event__c = eventNotPublished.Id;
        update subscribeConfigurationA1;
 
 
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualWarningCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Warning') {
                actualWarningCount++;   
            } 
        }
        
        // Assert :
        Integer expectedWarningCount = 1;
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String actualDescription = chainIdToDescription.get(chainA.Id);
        String expectedDescription = 'No publisher is configured to publish';
        System.assert(actualDescription.contains(expectedDescription));
 
    }  
    
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNotFirst() {

        // Arrange :
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;      

        Process__c SubscribeProcess  = new Process__c(Name = 'Subscribe');
        insert SubscribeProcess;
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       

 
        
        // Chain B - Problem : Subscribe Not first Step
        ChainStep__c chainStepB1 =  new ChainStep__c(Chain__c = chainB.Id, Process__c = wireTapProcess.Id, Sequence__c = 1);
        ChainStep__c chainStepB2 =  new ChainStep__c(Chain__c = chainB.Id, Process__c = SubscribeProcess.Id, Sequence__c = 2);       
        insert new List<ChainStep__c>{chainStepB1, chainStepB2};

        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;   
            }     
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualChainSubscribeNotLastStep = chainIdToDescription.get(chainB.Id);
        String expectedChainSubscribeNotLastStep = 'Subscribe process not  at front of chain';
        System.assertEquals(expectedChainSubscribeNotLastStep, actualChainSubscribeNotLastStep); 
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorGtOne() {


        // Arrange :
        Chain__c chainC = new Chain__c(Name = 'ChainC');
        insert chainC;
        
        Process__c SubscribeProcess  = new Process__c(Name = 'Subscribe');
        insert SubscribeProcess;
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       



        // Chain C - Problem : Subscribe Step Occurs more than once
        ChainStep__c chainStepC1 =  new ChainStep__c(Chain__c = chainC.Id, Process__c = SubscribeProcess.Id, Sequence__c = 1);
        ChainStep__c chainStepC2 =  new ChainStep__c(Chain__c = chainC.Id, Process__c = SubscribeProcess.Id, Sequence__c = 2);       
        insert new List<ChainStep__c>{chainStepC1, chainStepC2};
            
            
        // Event
        Event__c eventNotPublished = new Event__c(Name = 'an-event-not-published');
        insert eventNotPublished;

        

        
        // Config C1
        Id configurationIdC1 = (Id) [SELECT Id, Configuration__c 
                                   FROM ChainStep__c 
                                   WHERE Id = :chainStepC1.Id LIMIT 1].Configuration__c;
        SubscribeConfiguration__c  subscribeConfigurationC1 =  [SELECT Id, Event__c 
                                                              FROM SubscribeConfiguration__c 
                                                              WHERE Id = :configurationIdC1];
        subscribeConfigurationC1.Event__c = eventNotPublished.Id;
        update subscribeConfigurationC1;

        // Config C2
        Id configurationIdC2 = (Id) [SELECT Id, Configuration__c 
                                   FROM ChainStep__c 
                                   WHERE Id = :chainStepC2.Id LIMIT 1].Configuration__c;
        SubscribeConfiguration__c  subscribeConfigurationC2 =  [SELECT Id, Event__c 
                                                              FROM SubscribeConfiguration__c 
                                                              WHERE Id = :configurationIdC2];
        subscribeConfigurationC2.Event__c = eventNotPublished.Id;
        update subscribeConfigurationC2;
        
        
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;   
            }     
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = chainIdToDescription.get(chainC.Id);
        String expectedDescription = 'Subscribe appears more than once in chain';
        System.assert(actualDescription.contains(expectedDescription));    
    }


    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoConfig() {

        // Arrange :
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;      

        Process__c SubscribeProcess  = new Process__c(Name = 'Subscribe');
        insert SubscribeProcess;
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       

 
        
        // Chain B - Problem : No Configuration
        ChainStep__c chainStepB1 =  new ChainStep__c(Chain__c = chainB.Id, Process__c = SubscribeProcess.Id, Sequence__c = 1);
        ChainStep__c chainStepB2 =  new ChainStep__c(Chain__c = chainB.Id, Process__c = wireTapProcess.Id, Sequence__c = 2);       
        insert new List<ChainStep__c>{chainStepB1, chainStepB2};

        Id configurationIdB1 = (Id) [SELECT Id, Configuration__c 
                                     FROM ChainStep__c 
                                     WHERE Id = :chainStepB1.Id LIMIT 1].Configuration__c;
        Database.delete(configurationIdB1);
        
        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;   
            }     
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualChainSubscribeNotLastStep = chainIdToDescription.get(chainB.Id);
        String expectedChainSubscribeNotLastStep = 'Cannot resolve subscribe configuration';
        System.assertEquals(expectedChainSubscribeNotLastStep, actualChainSubscribeNotLastStep); 
    }
    
    static testMethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfig() {

        // Arrange :
        Chain__c chainB = new Chain__c(Name = 'ChainB');
        insert chainB;      

        Process__c SubscribeProcess  = new Process__c(Name = 'Subscribe');
        insert SubscribeProcess;
        Process__c wiretapProcess  = new Process__c(Name = 'Wiretap');
        insert wiretapProcess;       

 
        
        // Chain B - Problem : No Configuration
        ChainStep__c chainStepB1 =  new ChainStep__c(Chain__c = chainB.Id, Process__c = SubscribeProcess.Id, Sequence__c = 1);
        ChainStep__c chainStepB2 =  new ChainStep__c(Chain__c = chainB.Id, Process__c = wireTapProcess.Id, Sequence__c = 2);       
        insert new List<ChainStep__c>{chainStepB1, chainStepB2};


        // Act :
        List<HealthController.Health> SubscribeHealths =  Subscribe.getHealth(); 
        
        
        // Assemble :
        Map<id,string> chainIdToDescription = new Map<id,string>(); 
        Integer actualErrorCount = 0;
        for (HealthController.Health SubscribeHealth : SubscribeHealths ) {
            chainIdToDescription.put(SubscribeHealth.ChainId, SubscribeHealth.Detail);
            if (SubscribeHealth.Status == 'Error') {
                actualErrorCount++;   
            }     
        }
        
        // Assert :
        Integer expectedErrorCount = 1;
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = chainIdToDescription.get(chainB.Id);
        String expectedDescription = 'No event defined on subscribe configuration';
        System.assert(actualDescription.contains(expectedDescription));
    }

}