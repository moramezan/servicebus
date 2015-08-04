@IsTest private class PostInstallHandlerTest {

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
        Integer actualCountBefore = [SELECT COUNT() FROM NamespaceSetting__c];
        System.assertEquals(expectedCountBefore, actualCountBefore);
        
        //act
        PostInstallHandler handler = new PostInstallHandler();
        handler.upsertNamespaceSetting();
        
        //assert
        Integer expectedCountAfter = 1;
        Integer actualCountAfter = [SELECT COUNT() FROM NamespaceSetting__c];
        System.assertEquals(expectedCountAfter, actualCountAfter);
    }
    
    /**
     * test case for Winter '13 Known Issue: 
     * https://success.salesforce.com/issues_releases_view?release=180008002
     */
    static testMethod void testOnUpgradeSetsCustomSetting() {
        //assert
        Integer expectedCountBefore = 0;
        Integer actualCountBefore = [SELECT COUNT() FROM NamespaceSetting__c];
        System.assertEquals(expectedCountBefore, actualCountBefore);
        
        //act
        PostInstallHandler handler = new PostInstallHandler();
        handler.upsertNamespaceSetting();
        handler.upsertNamespaceSetting();
        
        //assert
        Integer expectedCountAfter = 1;
        Integer actualCountAfter = [SELECT COUNT() FROM NamespaceSetting__c];
        System.assertEquals(expectedCountAfter, actualCountAfter);
    }

}