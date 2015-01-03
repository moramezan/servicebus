@IsTest public class MonitorControllerTest {
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange processes, messages and controller
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = StepObject.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        MessageObjectSet.Inhibit = false;
        insert new Message__c(Parameters__c = '{"esb__SequenceName":"Test"}', Status__c = 'Queued');
        insert new Message__c(Parameters__c = '{"esb__SequenceName":"Test"}', Status__c = 'Buffered');
        MessageObjectSet.Inhibit = true;
        
        //act
        List<MonitorController.Statistic> statistics = MonitorController.getStatistics();
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        Integer count = MonitorController.getTestStatistics().size();
        System.assert(count > 1);
    }

}