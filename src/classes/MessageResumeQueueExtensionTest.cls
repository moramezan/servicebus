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
        insert new BrokerSetting__c(IsPaused__c = isPaused);

        //tee up two messages in queued state
        new Job(sequenceNameA, '000000000000000AAA').persist();
        new Job(sequenceNameA, '000000000000000AAA').persist();
        
        //assert
        Integer expectedBefore = 2;
        Integer actualBefore = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Paused'];
        System.assertEquals(expectedBefore, actualBefore, 'Wrong count before');
        
        //act - actions in the ctor
        MessageResumeQueueExtension.DoDml doDmlInstance = new MessageResumeQueueExtension.DoDml();

        //assemble
        Integer expectedAfter = 2;
        Integer actualAfter = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedAfter, actualAfter, 'Wrong count after.');
    }

    static testmethod void  callingDoResumeOnQueuedMessagesEnqueuesWakeup() {
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
        insert new BrokerSetting__c(IsPaused__c = isPaused);

        //tee up two messages in queued state
        new Job(sequenceNameA, '000000000000000AAA').persist();
        new Job(sequenceNameA, '000000000000000AAA').persist();
        Broker.impl().run();

        //act -
        List<Message__c> messages = [SELECT Id FROM Message__c];
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(messages);
        MessageResumeQueueExtension messageResumeQueueExtension =  new MessageResumeQueueExtension(controller);
        System.PageReference actualPageReference  = messageResumeQueueExtension.doResume();

        // assert
        Integer expectedJobs = 1;
        Integer actualJobs = Limits.getQueueableJobs();
        System.assertEquals(expectedJobs, actualJobs, 'Wakeup not enqueued.');
    }
    
}