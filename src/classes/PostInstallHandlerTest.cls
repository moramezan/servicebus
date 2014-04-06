@isTest private class PostInstallHandlerTest {
    static testMethod void callingInstallScheduleCorrectlyInstallsSchedule() {
        //arrange
        String  name = 'Eda Heartbeat';
        
        //assert
        Integer expectedSizeBefore = 0;
        Integer actualSizeBefore = [SELECT COUNT() FROM CronJobDetail WHERE Name = :name LIMIT 1];
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        
        //act
        PostInstallHandler.InstallSchedule();
        
        //assert
        Integer expectedSizeAfter = 1;
        Integer actualSizeAfter = [SELECT COUNT() FROM CronJobDetail WHERE Name = :name LIMIT 1];
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        
    }

    static testMethod void testOnInstallSendsEmail() {
        //assert
        Integer expectedInvocationsBefore = 0;
        Integer actualInvocationsBefore = Limits.getEmailInvocations();
        System.assertEquals(expectedInvocationsBefore, actualInvocationsBefore);
        
        //act
        InstallHandler handler = new PostInstallHandler();
        Test.testInstall(handler, new Version(1, 0));
        
        //assert
        Integer expectedInvocationsAfter = 1;
        Integer actualInvocationsAfter = Limits.getEmailInvocations();
        System.assertEquals(expectedInvocationsAfter, actualInvocationsAfter);
    }

}