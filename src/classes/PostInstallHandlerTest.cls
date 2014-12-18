@IsTest private class PostInstallHandlerTest {
    static testmethod void callingInstallScheduleCorrectlyInstallsSchedule() {
        //arrange
        String  name = 'Heartbeat (do not delete)';
        
        //act
        PostInstallHandler.InstallSchedule();
        
        //assert
        Integer expectedSizeAfter = 1;
        Integer actualSizeAfter = [SELECT COUNT() FROM CronJobDetail WHERE Name = :name LIMIT 1];
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        
    }

    static testmethod void testOnInstallSendsEmail() {
        //assert
        Integer expectedInvocationsBefore = 0;
        Integer actualInvocationsBefore = Limits.getEmailInvocations();
        System.assertEquals(expectedInvocationsBefore, actualInvocationsBefore);
        
        //act
        InstallHandler handler = new PostInstallHandler();
        ProcessDiscoverBatch.classes = new List<ApexClass>();
        Test.testInstall(handler, null, false);
        
        //assert
        Integer expectedInvocationsAfter = 1;
        Integer actualInvocationsAfter = Limits.getEmailInvocations();
        System.assertEquals(expectedInvocationsAfter, actualInvocationsAfter);
    }
    
    static testmethod void testPermissionSetAssignmentCreated() {
        //arrange new user
        User user = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            Username = DateTime.now().getTime() + 'test@test.com',
            Alias = 'mgr',
            LastName = 'Test',
            LocaleSidKey = 'en_US',
            Email = 'test@example.com',
            CommunityNickname = 'mgr',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            TimeZoneSidKey = 'Australia/Sydney'
        );
        insert user;
        
        System.runAs(user) {
            //act
            Test.startTest();
            Integer countBefore = [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :user.Id];
            PostInstallHandler.assignPermissionSet(user.Id);
            Test.stopTest();
            
            //assert
            Integer expectedCount = countBefore + 1;
            Integer actualCount = [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :user.Id];
            System.assertEquals(expectedCount, actualCount);
        }
    }
    
    static testmethod void testWiretapSettingsCreated() {
        //arrange user
        Id userId = UserInfo.getUserId();
        
        //act
        Test.startTest();
        Integer countBefore = [SELECT COUNT() FROM WiretapSetting__c];
        PostInstallHandler.createWiretapSettings(userId);
        Test.stopTest();
        
        //assert
        Integer expectedCount = countBefore + 1;
        Integer actualCount = [SELECT COUNT() FROM WiretapSetting__c];
        System.assertEquals(expectedCount, actualCount);
    }

}