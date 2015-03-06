@IsTest public class MonitorControllerTest {
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange processes, messages and controller
        Process__c wiretapProcess = ProcessModel.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = StepModel.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);
        
        MessageSetModel.Inhibit = false;
        insert new Message__c(FullyQualifiedClassName__c = wiretapProcess.FullyQualifiedClassName__c, Event__c = '{"esb__SequenceName":"Test"}', Status__c = 'Queued');
        insert new Message__c(FullyQualifiedClassName__c = terminateProcess.FullyQualifiedClassName__c, Event__c = '{"esb__SequenceName":"Test"}', Status__c = 'Buffered');
        MessageSetModel.Inhibit = true;
        
        //act
        List<MonitorController.Statistic> statistics = MonitorController.getStatistics();
        
        //assert
        Integer expectedCount = 2 + 1; //one extra for buffered guys - they have no process name so the graph is [' ', 'Wiretap', 'Terminate']
        Integer actualCount = statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        Integer count = MonitorController.getTestStatistics().size();
        System.assert(count > 1);
    }

}