public class PostInstallClass implements InstallHandler {

    public void onInstall(InstallContext context) {
        // if(context.previousVersion() == null) {}

        installSchedule();
    }

    @TestVisible
    private static void installSchedule() {
        String  name = 'Eda Heartbeat';
        List<CronJobDetail>  cronJobDetails = [SELECT  Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        if (cronJobDetails.size() == 0) {
           String chron_exp = '0 0 * * * ?';
           ScheduleDispatcher scheduleDispatcher = new ScheduleDispatcher();
           System.schedule(name ,chron_exp,scheduleDispatcher);
        }
    }
}