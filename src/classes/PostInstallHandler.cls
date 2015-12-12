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
        Id installerId = context == null ? UserInfo.getUserId() : context.installerId();
        Boolean isUpgrade = context == null ? false : context.isUpgrade();
        Boolean isPush = context == null ? false : context.isPush();
        Boolean isCli = context == null;
        
        //only nag about the remote site setting on first install
        if (!isUpgrade && !isCli) sendNotification(installerId);
        
        //create slots for the first time
        if (!isUpgrade) this.upsertSlots();
        
        //create broker setting (version)
        if (!isUpgrade) this.upsertApplication();
    }
    
    /**
     * Creates "slots" per #1103
     * 0001, 0002 ... 0999, 1000
     */
    @TestVisible void upsertSlots() {
        List<Slot__c> slots = new List<Slot__c>();
        for (Integer i = 1; i <= 1000; i++) slots.add(new Slot__c(Name = String.valueOf(i).leftPad(4).replace(' ', '0')));
        upsert slots Name;
    }
    
    /**
     * For namespace neutrality, this helps custom button code
     * to determine fully-qualified object and apex class names.
     */
    @TestVisible void upsertApplication() {
        Application__c application = Application__c.getOrgDefaults();
        application.PrefixBar__c = SObjectType.Application__c.Name.substringBefore('Application__c');
        application.PrefixDot__c = PostInstallHandler.class.getName().substringBefore('PostInstallHandler');
        application.Prefix__c = PostInstallHandler.class.getName().substringBefore('PostInstallHandler').substringBefore('.');
        upsert application;
    }
    
    /**
     * Notify them (and us) on package install
     */
    static void sendNotification(Id userId) {
        //notify the installing user
        User user = [
            SELECT Id, FirstName, Email
            FROM User
            WHERE Id = :userId
        ];
        
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSenderDisplayName('Eeyore');
        message.setReplyTo('webmaster@bigassforce.com');
        message.setSubject('Did you configure Service Bus?');
        message.setCcAddresses(new List<String>{'webmaster@bigassforce.com'});
        message.setTargetObjectId(user.Id);
        message.setSaveAsActivity(false);
        message.setPlainTextBody(''
            + 'hey ' + user.FirstName + ','
            + '\n\n'
            + '    your Service Bus package has installed alright.'
            + '\n\n'
            + 'Please feel free to reach out if you have any difficulties'
            + '\nwith Service Bus, and we can better learn how people apply it.'
            + '\n\n'
            + 'best regards,'
            + '\nEeyore'
            + '\nwebmaster@bigass.io'
        );
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
        } catch (EmailException e) {
            //eg sandbox with no access to send email
        }
    }
    
}