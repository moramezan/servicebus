@IsTest class MonitorControllerTest {
    
    @TestSetup static void testSetup() {
        //act
        upsert BrokerSetting__c.getOrgDefaults();
        
        //assert
        System.assertNotEquals(null, BrokerSetting__c.getOrgDefaults().Id, 'Wrong Id.');
    }
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange services, messages and controller
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        Test.startTest();
        Job job = new Job('Test', '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        Broker.impl().run();
        
        //act
        List<MonitorController.Statistic> statistics = MonitorController.fetchStatistics();
        
        //assert 1 null, //#1114 no ALL ROWS in fetchStatistics means they disappear again
        Integer expectedCount = 1; //the graph is [' ']
        Integer actualCount = statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        Integer count = MonitorController.fetchTestStatistics().size();
        System.assert(count > 1);
    }

}