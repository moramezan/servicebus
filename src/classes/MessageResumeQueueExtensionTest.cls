@IsTest private class MessageResumeQueueExtensionTest {

   static testmethod void  callingDoDmlCtorCorrectlyResolvesFromQueuedToBufferedAndCorrectlySetsPause() {
        // arrange
        Boolean isPaused =  true;
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA6 = 2;

        Step__c stepA1 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA1,Process__c = wiretapProcess.Id);
        Step__c stepA6 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA6,Process__c = terminateProcess.Id);

        insert stepA1;
        insert stepA6;

        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);

        //tee up two messages in queued state
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        Broker.enqueue(sequenceNameA, '000000000000000AAA');

        //act - actions in the ctor
        MessageResumeQueueExtension.DoDml doDmlInstance = new MessageResumeQueueExtension.DoDml();

        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Process__r.Name, Step__c , Parameters__c, Status__c, Exception__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];

       BrokerSettings__c actualSettings  = BrokerSettings__c.getInstance();
       Boolean actualIsPaused =  actualSettings.IsPaused__c;
       
       Integer actualCount = messages.size();
       Boolean actualBuffered = true;
       for (Message__c message : messages) {
           if (message.Status__c != 'Buffered') {
               actualBuffered = false;    
           }
       }

       // assert
       Integer expectedCount = 2;
       System.assertEquals( expectedCount, actualCount);
       Boolean expectedBuffered = true;
       System.assertEquals( expectedBuffered, actualBuffered);
       Boolean expectedIsPaused =  false;
       System.assertEquals( expectedIsPaused, actualIsPaused);
    }

    
    

        
   static testmethod void  callingDoResumeOnQueuedMessagesProcessesMessages() {
        // arrange
        Boolean isPaused =  true;
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA6 = 2;

        Step__c stepA1 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA1,Process__c = wiretapProcess.Id);
        Step__c stepA6 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA6,Process__c = terminateProcess.Id);

        insert stepA1;
        insert stepA6;

        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);

        //tee up two messages in queued state
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        Broker.enqueue(sequenceNameA, '000000000000000AAA');

        //act -
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController([SELECT Id, Name FROM Message__c]);
        MessageResumeQueueExtension messageResumeQueueExtension =  new MessageResumeQueueExtension(controller);
        System.PageReference actualPageReference  = messageResumeQueueExtension.doResume();

       // assert
       Integer expectedCount = 2 + 2;
       Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];
       System.assertEquals( expectedCount, actualCount);
       String expectedPageReference = SObjectType.Message__c.KeyPrefix;
       System.Assert(actualPageReference.getUrl().contains(expectedPageReference));
    }  
    
}