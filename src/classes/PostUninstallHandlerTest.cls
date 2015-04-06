@IsTest private class PostUninstallHandlerTest {

    static testmethod void callingUnInstallScheduleCorrectlyUnInstallsSchedule() {

        //arrange
        String  name = 'Enterprise Service Bus Heartbeat';
        ConfigureController.installSchedule();
        List<CronJobDetail>  cronJobDetailsBefore = [SELECT  Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        Integer actualSizeBefore = cronJobDetailsBefore.size();

        //act
        ConfigureController.uninstallSchedule();

        //assemble
        List<CronJobDetail>  cronJobDetailsAfter = [SELECT  Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        Integer actualSizeAfter = cronJobDetailsAfter.size();

        //act
        Integer expectedSizeBefore = 1;
        Integer expectedSizeAfter = 0;
        System.assertEquals( expectedSizeBefore, actualSizeBefore );
        System.assertEquals( expectedSizeAfter, actualSizeAfter );
        
    }

}