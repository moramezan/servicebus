@IsTest class PostInstallHandlerTest {

    static testmethod void testOnInstallSendsEmail() {
        //assert
        Integer expectedInvocationsBefore = 0;
        Integer actualInvocationsBefore = Limits.getEmailInvocations();
        System.assertEquals(expectedInvocationsBefore, actualInvocationsBefore);
        
        //act
        InstallHandler handler = new PostInstallHandler();
        Test.testInstall(handler, null, false);
        
        //assert
        Integer expectedInvocationsAfter = 1;
        Integer actualInvocationsAfter = Limits.getEmailInvocations();
        System.assertEquals(expectedInvocationsAfter, actualInvocationsAfter);
    }

    static testMethod void testOnInstallSetsCustomSetting() {
        //assert
        Integer expectedCountBefore = 0;
        Integer actualCountBefore = [SELECT COUNT() FROM Application__c];
        System.assertEquals(expectedCountBefore, actualCountBefore);
        
        //act
        PostInstallHandler handler = new PostInstallHandler();
        handler.upsertApplication();
        
        //assert
        Integer expectedCountAfter = 1;
        Integer actualCountAfter = [SELECT COUNT() FROM Application__c];
        System.assertEquals(expectedCountAfter, actualCountAfter);
        
        //assert
        Decimal expectedVersion = 1.0;
        Decimal actualVersion = Application__c.getOrgDefaults().RouterVersion__c;
        System.assertEquals(expectedVersion, actualVersion, 'Wrong version.');
        
        //assert
        Id expectedId = UserInfo.getUserId();
        Id actualId = Application__c.getOrgDefaults().RunAsUserId__c;
        System.assertEquals(expectedId, actualId, 'Wrong Id.');
    }
    
    /**
     * test case for Winter '13 Known Issue:
     * https://success.salesforce.com/issues_releases_view?release=180008002
     */
    static testMethod void testOnUpgradeCouldUpsertWithoutExceptions() {
        //assert
        Integer expectedCountBefore = 0;
        Integer actualCountBefore = [SELECT COUNT() FROM Application__c];
        System.assertEquals(expectedCountBefore, actualCountBefore);
        
        //act
        PostInstallHandler handler = new PostInstallHandler();
        handler.upsertApplication();
        handler.upsertApplication();
        
        //assert
        Integer expectedCountAfter = 1;
        Integer actualCountAfter = [SELECT COUNT() FROM Application__c];
        System.assertEquals(expectedCountAfter, actualCountAfter);
    }
    
    static testmethod void testUpsertSlots() {
        //assert
        Integer expectedCount = 0;
        Integer actualCount = [SELECT COUNT() FROM Slot__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong count before.');
        
        //act
        new PostInstallHandler().upsertSlots();
        
        //assert
        expectedCount = 1000;
        actualCount = [SELECT COUNT() FROM Slot__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong count after.');
        
        //assemble
        List<Slot__c> slots = [SELECT Id, Name FROM Slot__c ORDER BY Name ASC];
        
        //assert
        System.assertEquals('0001', slots[0].Name, 'Wrong first name.');
        System.assertEquals('1000', slots[999].Name, 'Wrong last name.');
    }

}