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
        
        Step__c debugStep = SequenceModel.fromName(sequence.Name).appendStep(DebugService.class.getName());
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => 'Test'});
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