@IsTest public class MonitorControllerTest {
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange processes, messages and controller
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        insert new Message__c(Event__c = '{"esb__SequenceName":"Test"}', Status__c = 'Paused');
        insert new Message__c(Event__c = '{"esb__SequenceName":"Test"}', Status__c = 'Buffered');
        
        //act
        List<MonitorController.Statistic> statistics = MonitorController.getStatistics();
        
        //assemble
        Set<Id> apexClassIds = new Map<Id,SObject>([SELECT Id FROM ApexClass LIMIT 10000]).keySet();
        ApexClassSetModel model = ApexClassSetModel.discoverProcesses(apexClassIds);
        
        //assert 1 null, 1 wiretap, 1 terminate,
        Integer expectedCount = 3; //the graph is [' ', 'Wiretap', 'Terminate']
        Integer actualCount = statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        Integer count = MonitorController.getTestStatistics().size();
        System.assert(count > 1);
    }

}