@isTest
private class PostUninstallClassTest {

    static testMethod void callingUnInstallScheduleCorrectlyUnInstallsSchedule() {

        //arrange
        String  name = 'Eda Heartbeat';
        PostInstallClass.InstallSchedule();
        List<CronJobDetail>  cronJobDetailsBefore = [SELECT  Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        Integer actualSizeBefore = cronJobDetailsBefore.size();

        //act
        PostUnInstallClass.UnInstallSchedule();

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