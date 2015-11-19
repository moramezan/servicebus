@IsTest class ApprovalUnlockTest {
    
    static testmethod void testUnlockInvoked() {
        //arrange
        Account account = new Account(Name = 'test');
        insert account;
        Approval.Lock(account);
        Map<String,Object> inputEvent = new Map<String,Object>{'RecordId' => account.Id};
        Test.startTest();

        //assert
        Integer expectedChunks = 0;
        Integer actualChunks = Limits.getDmlStatements();
        System.assertEquals(expectedChunks, actualChunks, 'Wrong chunks before.');
        
        //act
        ApexClassModel.Service service = new ApprovalUnlock();
        service.handle(inputEvent);
        
        //assert
        expectedChunks = 1;
        actualChunks = Limits.getDmlStatements();
        System.assertEquals(expectedChunks, actualChunks, 'Wrong chunks after.');
    }
    
    static testmethod void testChunks() {
        //assert
        Integer expectedChunks = Limits.getLimitDmlStatements();
        Integer actualChunks = new ApprovalLock.Summary().Chunks;
        System.assertEquals(expectedChunks, actualChunks, 'Wrong chunks.');
    }

}