@isTest
private class PostInstallClassTest {
    static testMethod void callingInstallScheduleCorrectlyInstallsSchedule() {
        
        //arrange
 		String  name = 'Eda Heartbeat';
        List<CronJobDetail>  cronJobDetailsBefore = [SELECT  Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        Integer actualSizeBefore = cronJobDetailsBefore.size();
        
        //act
        PostInstallClass.InstallSchedule();
 
        //assemble
        List<CronJobDetail>  cronJobDetailsAfter = [SELECT  Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        Integer actualSizeAfter = cronJobDetailsAfter.size();
        
        //act
        Integer expectedSizeBefore = 0;
        Integer expectedSizeAfter = 1;
        System.assertEquals( expectedSizeBefore, actualSizeBefore );     
        System.assertEquals( expectedSizeAfter, actualSizeAfter );
        
    }

}