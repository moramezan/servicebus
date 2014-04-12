public class PostInstallHandler implements InstallHandler {

    /**
     * Id organizationId();
     * Id installerId();
     * Boolean isUpgrade();
     * Boolean isPush(); 
     * Version previousVersion();
     */
    public void onInstall(InstallContext context) {
        installSchedule();
        sendRemoteSiteSettingNag(context);
        executeProcessDiscoverBatch();
    }
    
    /**
     * Kick off process discovery in the background
     */
    @TestVisible static private void executeProcessDiscoverBatch() {
        AsyncApexJobs jobs = AsyncApexJobs.runOne(ProcessDiscoverBatch.class, 1);
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
            + 'It\'s crucial to click the [CONFIGURE] button and then follow'
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