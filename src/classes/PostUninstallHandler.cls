/**
 * This class is WITHOUT SHARING to ensure the InstallHandler user context can access CronJobDetail etc
 * See http://salesforce.stackexchange.com/q/258/320 and http://salesforce.stackexchange.com/q/32607/320
 */
public without sharing class PostUninstallHandler implements UnInstallHandler {

    public void onUninstall(UninstallContext context) {
        unInstallSchedule();
    }


    @TestVisible
    private static void uninstallSchedule() {
        String  name = 'Heartbeat (do not delete)';
        List<CronJobDetail>  cronJobDetails = [SELECT   Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        if (cronJobDetails.size() > 0) {
            Id cronJobDetailId = cronJobDetails[0].Id;
            List<CronTrigger>  cronTriggers = [SELECT   Id, CronJobDetailId FROM CronTrigger  WHERE CronJobDetailId = :cronJobDetailId ];
            if (cronTriggers.size() > 0) {
                system.abortJob(cronTriggers[0].Id);
            }
        }
    }
}