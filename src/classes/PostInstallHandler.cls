/**
 * This class is WITHOUT SHARING to ensure the InstallHandler user context can access CronJobDetail etc
 * See http://salesforce.stackexchange.com/q/258/320 and http://salesforce.stackexchange.com/q/32607/320
 */
public without sharing class PostInstallHandler implements InstallHandler {

    /**
     * Id organizationId();
     * Id installerId();
     * Boolean isUpgrade();
     * Boolean isPush(); 
     * Version previousVersion();
     */
    public void onInstall(InstallContext context) {
        //push upgrades run under the pushing user, not the local user, so keep it simple
        if (!context.isPush()) installSchedule(context.installerId());
        
        sendRemoteSiteSettingNag(context);
        
        executeProcessDiscoverBatch();
    }
    
    /**
     * Kick off process discovery in the background
     */
    @TestVisible static private void executeProcessDiscoverBatch() {
        AsyncApexJobs jobs = AsyncApexJobs.runOne(ProcessDiscoverBatch.class, 1);
    }
    
    /**
     * Creates the hourly cron job used by Schedule process steps.
     * Also makes sure the cron job will use the Batch Broker.
     * 
     * @param userId The real user id of the person who installed the package.
     */
    @TestVisible private static void installSchedule(Id userId) {
        String name = 'Heartbeat (do not delete)';
        List<CronJobDetail> cronJobDetails = [SELECT Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        
        //job already scheduled, nothing to do
        if (!cronJobDetails.isEmpty()) return;
        
        String cronExpr = '0 0 * * * ?';
        HeartbeatDispatcher schedulable = new HeartbeatDispatcher();
        System.schedule(name, cronExpr, schedulable);
    }
    
    /**
     * Notify them (and us) on package install
     */
    static private void sendRemoteSiteSettingNag(InstallContext context) {
        User user;
        if (context.isPush()) {
            //push upgrade should notify sysadmins
            user = [
                SELECT Id, FirstName, Email
                FROM User
                WHERE Profile.Name = 'System Administrator'
                ORDER BY LastLoginDate DESC
                LIMIT 1
            ];
        } else {
            //normal install should notify installer
            user = [
                SELECT Id, FirstName, Email
                FROM User
                WHERE Id = :context.installerId()
            ];
        }
        
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSenderDisplayName('Eeyore');
        message.setReplyTo('webmaster@bigassforce.com');
        message.setSubject('Did you configure EDA?');
        message.setCcAddresses(new List<String>{'webmaster@bigassforce.com'});
        message.setTargetObjectId(user.Id);
        message.setSaveAsActivity(false);
        message.setPlainTextBody(''
            + 'hey ' + user.FirstName + ','
            + '\n\n'
            + '    your Event Driven Architecture package has installed alright.'
            + '\n\n'
            + 'But now you must click [Configure] on the package and follow'
            + '\nthe on-screen instructions if you have not already done so:'
            + '\n\n'
            + Url.getSalesforceBaseUrl().toExternalForm().replace('http:', 'https:') + Page.Configure.getUrl()
            + '\n\n'
            + 'Please feel free to reach out if you have any difficulties'
            + '\nwith EDA, and I can better learn how people apply it :-)'
            + '\n\n'
            + 'best regards,'
            + '\nEeyore'
            + '\nwebmaster@bigassforce.com'
        );
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
        } catch (Exception e) {
            //eg sandbox with no access to send email
        }
    }
}