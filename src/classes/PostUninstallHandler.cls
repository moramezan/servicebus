/**
 * This class is WITHOUT SHARING to ensure the InstallHandler user context can access CronJobDetail etc
 * See http://salesforce.stackexchange.com/q/258/320 and http://salesforce.stackexchange.com/q/32607/320
 */
public without sharing class PostUninstallHandler implements UnInstallHandler {

    public void onUninstall(UninstallContext context) {
        //can't script uninstall of cron job, it actually blocks uninstall first
    }

}