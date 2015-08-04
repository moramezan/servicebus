@IsTest public class MonitorControllerTest {
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange processes, messages and controller
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        insert new Message__c(ApexClassName__c = Wiretap.class.getName(), Event__c = '{"esb__SequenceName":"Test"}', Status__c = 'Queued');
        insert new Message__c(ApexClassName__c = Terminate.class.getName(), Event__c = '{"esb__SequenceName":"Test"}', Status__c = 'Buffered');
        
        //act
        List<MonitorController.Statistic> statistics = MonitorController.getStatistics();
        
        //assemble
        List<ApexClass> apexClasses = [SELECT Id FROM ApexClass WHERE Name != 'ApexClassModel'];
        ApexClassSetModel model = new ApexClassSetModel(apexClasses);
        model.discoverProcesses();
        
        //assert
        Integer expectedCount = model.toDtos().size() + 1; //one extra for buffered guys - they have no process name so the graph is [' ', 'Wiretap', 'Terminate']
        Integer actualCount = statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        Integer count = MonitorController.getTestStatistics().size();
        System.assert(count > 1);
    }

}