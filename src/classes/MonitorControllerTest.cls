@IsTest class MonitorControllerTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange services, messages and controller
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(WiretapService.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class);
        
        Test.startTest();
        Job job = new Job('Test', '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        Broker.impl().run();
        
        //act
        List<MonitorController.Statistic> statistics = MonitorController.fetchStatistics();
        
        //assert 1 null, //#1114 no ALL ROWS in fetchStatistics means they disappear again
        Integer expectedCount = 3; //the graph is [' ', '1#Test#1', '1#Test#2']
        Integer actualCount = statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        Integer count = MonitorController.fetchTestStatistics().size();
        System.assert(count > 1);
    }

}