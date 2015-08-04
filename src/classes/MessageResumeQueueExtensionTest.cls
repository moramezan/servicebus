@IsTest private class MessageResumeQueueExtensionTest {

    static testmethod void  callingDoDmlCtorCorrectlyResolvesFromQueuedToBufferedAndCorrectlySetsPause() {
        // arrange
        Boolean isPaused =  true;

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA6 = 2;

        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA6 = SequenceModel.fromName(sequenceA.Name).appendStep(Terminate.class);

        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.SynchronousBroker.class.getName(), IsPaused__c = isPaused);

        //tee up two messages in queued state
        new Job(sequenceNameA, '000000000000000AAA').execute(null);
        new Job(sequenceNameA, '000000000000000AAA').execute(null);
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c != 'Completed'];
        System.assertEquals(expectedCount, actualCount, 'Wrong count before');
        
        //act - actions in the ctor
        MessageResumeQueueExtension.DoDml doDmlInstance = new MessageResumeQueueExtension.DoDml();

        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Event__c, Status__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];

        BrokerSetting__c actualSettings  = BrokerSetting__c.getInstance();
        Boolean actualIsPaused =  actualSettings.IsPaused__c;
        
        expectedCount = 0;
        actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount, 'Wrong count after');
    }

    
    

        
    static testmethod void  callingDoResumeOnQueuedMessagesProcessesMessages() {
        // arrange
        Boolean isPaused =  true;

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA6 = 2;

        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA6 = SequenceModel.fromName(sequenceA.Name).appendStep(Terminate.class);

        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.SynchronousBroker.class.getName(), IsPaused__c = isPaused);

        //tee up two messages in queued state
        new Job(sequenceNameA, '000000000000000AAA').execute(null);
        new Job(sequenceNameA, '000000000000000AAA').execute(null);

        //act -
        List<Message__c> messages = [SELECT Id FROM Message__c];
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(messages);
        MessageResumeQueueExtension messageResumeQueueExtension =  new MessageResumeQueueExtension(controller);
        System.PageReference actualPageReference  = messageResumeQueueExtension.doResume();

        // assert
        Integer expectedCount = 2 + 2;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
    }
    
}