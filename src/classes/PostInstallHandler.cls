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
        
        //push upgrades run under the pushing user, not the local user, so keep it simple
        if (!isPush) installSchedule();
        
        //permission set assignments must be made on the local user, not the pushing user
        if (!isPush) assignPermissionSet(installerId);
        
        //only nag about the remote site setting on first install
        if (!isUpgrade && !isCli) sendNotification(installerId);
        
        //wiretap should send to sysadmin, to prevent confusion with schedule processes
        if (!isPush) createWiretapSettings(installerId);
        
        //synchronously install our processes
        if (!isPush) initializeProcesses();
        
        executeProcessDiscoverBatch();
    }
    
    /**
     * We can generate OUR processes synchronously. This means the sequence builder
     * will be available immediately. The batch will get around to THEIR processes.
     */
    static public void initializeProcesses() {
        List<Process__c> processes = new List<Process__c>{
            ProcessObject.fromType(Type.forName(AuditInitializer.class.getName())),
            ProcessObject.fromType(Type.forName(AuditWriter.class.getName())),
            ProcessObject.fromType(Type.forName(Branch.class.getName())),
            ProcessObject.fromType(Type.forName(Gate.class.getName())),
            ProcessObject.fromType(Type.forName(Jump.class.getName())),
            ProcessObject.fromType(Type.forName(Mark.class.getName())),
            ProcessObject.fromType(Type.forName(Publish.class.getName())),
            ProcessObject.fromType(Type.forName(Schedule.class.getName())),
            ProcessObject.fromType(Type.forName(Subscribe.class.getName())),
            ProcessObject.fromType(Type.forName(Subsequence.class.getName())),
            ProcessObject.fromType(Type.forName(Terminate.class.getName())),
            ProcessObject.fromType(Type.forName(Wiretap.class.getName()))
        };
        
        upsert processes FullyQualifiedClassName__c;
    }
    
    /**
     * Assign Orchestrator permission set to the installer
     * (Performed in a FUTURE method to prevent MIXED_DML_OPERATION exception)
     */
    @Future static public void assignPermissionSet(Id userId) {
        //resolve package namespace prefix
        String namespacePrefix = PostInstallHandler.class.getName().substringBefore('PostInstallHandler').substringBefore('.');
        
        //find installed permission set
        PermissionSet ps = [
            SELECT Id
            FROM PermissionSet
            WHERE NamespacePrefix = :namespacePrefix
            AND Name = 'AdministerEsb'
        ];
        
        //determine if it has been assigned already
        Integer psas = [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE PermissionSetId = :ps.Id
            AND AssigneeId = :userId
        ];
        
        //if not, assign it to whoever installs the package
        if (psas == 0) insert new PermissionSetAssignment(
            PermissionSetId = ps.Id,
            AssigneeId = userId
        );
    }
    
    /**
     * Kick off process discovery in the background
     *
     * AsyncApexJobObject.runOne would need to be WITHOUT SHARING to see AsyncApexJob
     * because the InstallHandler user context cannot access that table. So here
     * we just use Database.executeBatch as it's unlikely to already be running.
     */
    static public void executeProcessDiscoverBatch() {
        Database.executeBatch(new ProcessDiscoverBatch(), 1);
    }
    
    /**
     * Creates the hourly cron job used by Schedule process steps.
     * Also makes sure the cron job will use the Batch Broker.
     */
    static public Id installSchedule() {
        String name = 'Heartbeat (do not delete)';
        List<CronJobDetail> cronJobDetails = [SELECT Id, Name FROM CronJobDetail WHERE Name = :name LIMIT 1];
        
        //job already scheduled, nothing to do
        if (!cronJobDetails.isEmpty()) return null;
        
        String cronExpr = '0 0 * * * ?';
        HeartbeatDispatcher schedulable = new HeartbeatDispatcher();
        return System.schedule(name, cronExpr, schedulable);
    }
    
    /**
     * Notify them (and us) on package install
     */
    static private void sendNotification(Id userId) {
        //notify the installing user
        User user = [
            SELECT Id, FirstName, Email
            FROM User
            WHERE Id = :userId
        ];
        
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSenderDisplayName('Eeyore');
        message.setReplyTo('webmaster@bigassforce.com');
        message.setSubject('Did you configure ESB?');
        message.setCcAddresses(new List<String>{'webmaster@bigassforce.com'});
        message.setTargetObjectId(user.Id);
        message.setSaveAsActivity(false);
        message.setPlainTextBody(''
            + 'hey ' + user.FirstName + ','
            + '\n\n'
            + '    your Enterprise Service Bus package has installed alright.'
            + '\n\n'
            + 'Please feel free to reach out if you have any difficulties'
            + '\nwith ESB, and we can better learn how people apply it.'
            + '\n\n'
            + 'best regards,'
            + '\nEeyore'
            + '\nwebmaster@bigass.io'
        );
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
        } catch (Exception e) {
            //eg sandbox with no access to send email
        }
    }
    
    /**
     * Set the Wiretap Settings
     * (Performed in a FUTURE method to prevent MIXED_DML_OPERATION exception)
     */
    @Future static public void createWiretapSettings(Id userId) {
        //fetch custom setting or create it for the first time
        WiretapSetting__c setting = WiretapSetting__c.getOrgDefaults();
        if (setting == null) setting = new WiretapSetting__c();
        
        //write the values
        setting.UserId__c = userId;
        upsert setting;
    }
}