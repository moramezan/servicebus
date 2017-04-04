@IsTest class BrokerBatchTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    class MockJob implements System.Schedulable {
        public void execute(System.SchedulableContext context) {}
    }
    
    class BatchableContext implements Database.BatchableContext {
        Id jobId;
        public BatchableContext() {this.jobId = System.schedule('test', '0 0 * * * ?', new MockJob());}
        public Id getJobId() {return this.jobId;}
        public Id getChildJobId() {return this.jobId;}
    }
    
    static testmethod void coverStart() {
        //arrange
        BrokerBatch dispatcher = new BrokerBatch();
        
        //act
        Object iterator = dispatcher.start(new BatchableContext());
        
        //assert
        System.assert(iterator instanceof Iterable<SObject>);
    }
    
    static testmethod void coverExecute() {
        //arrange
        List<Slot__c> slots = new List<Slot__c>{new Slot__c(Name = '0000')};
        
        //arrange mock
        AsyncApexJob mock = (AsyncApexJob)Json.deserialize('{"TotalJobItems":0}', AsyncApexJob.class);
        BatchableContext context = new BatchableContext();
        ApexDomain.setById(context.getJobId(), mock);
        
        //act
        BrokerBatch dispatcher = new BrokerBatch();
        dispatcher.execute(context, slots);
        
        //assert
        System.assert(!slots.isEmpty());
    }
    
    static testmethod void coverFinish() {
        //arrange mock
        AsyncApexJob mock = (AsyncApexJob)Json.deserialize('{"TotalJobItems":0}', AsyncApexJob.class);
        BatchableContext context = new BatchableContext();
        ApexDomain.setById(context.getJobId(), mock);
        
        //act
        BrokerBatch batch = new BrokerBatch();
        batch.finish(context);
        
        //assert
        Integer expectedCount = 0;
        Integer actualcount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount);
    }
}