@IsTest public class MonitorControllerTest {
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange processes, messages and controller
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
        List<MonitorController.Statistic> statistics = MonitorController.getStatistics();
        
        //assemble
        Set<Id> apexClassIds = new Map<Id,SObject>([
            SELECT Id
            FROM ApexClass
            WHERE Name IN ('Wiretap', 'Terminate')
            LIMIT 10000
        ]).keySet();
        ApexClassSetModel model = ApexClassSetModel.discoverProcesses(apexClassIds);
        
        //assert 1 null, 1 wiretap, 1 terminate,
        Integer expectedCount = 3; //the graph is [' ', 'Test#1', 'Test#2']
        Integer actualCount = statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        Integer count = MonitorController.getTestStatistics().size();
        System.assert(count > 1);
    }

}