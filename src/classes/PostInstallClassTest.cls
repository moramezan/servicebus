@isTest
private class PostInstallClassTest {
    static testMethod void callingInstallScheduleCorrectlyInstallsSchedule() {
        //arrange
        String  name = 'Eda Heartbeat';
        
        //assert
        Integer expectedSizeBefore = 0;
        Integer actualSizeBefore = [SELECT COUNT() FROM CronJobDetail WHERE Name = :name LIMIT 1];
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        
        //act
        PostInstallClass.InstallSchedule();
        
        //assert
        Integer expectedSizeAfter = 1;
        Integer actualSizeAfter = [SELECT COUNT() FROM CronJobDetail WHERE Name = :name LIMIT 1];
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        
    }

}