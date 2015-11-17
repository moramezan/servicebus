@IsTest class ApprovalLockTest {
    
    static testmethod void testLockInvoked() {
        //arrange
        Account account = new Account(Name = 'test');
        insert account;
        Map<String,Object> inputEvent = new Map<String,Object>{'RecordId' => account.Id};
        Test.startTest();

        //assert
        Integer expectedLimits = 0;
        Integer actualLimits = Limits.getDmlStatements();
        System.assertEquals(expectedLimits, actualLimits, 'Wrong limits before.');
        
        //act
        ApexClassModel.Service service = new ApprovalLock();
        service.handle(inputEvent);
        
        //assert
        expectedLimits = 1;
        actualLimits = Limits.getDmlStatements();
        System.assertEquals(expectedLimits, actualLimits, 'Wrong limits after.');
    }
    
    static testmethod void testLimits() {
        //assert
        Integer expectedLimits = Limits.getLimitDmlStatements();
        Integer actualLimits = new ApprovalLock.Summary().Limits;
        System.assertEquals(expectedLimits, actualLimits, 'Wrong limits.');
    }

}