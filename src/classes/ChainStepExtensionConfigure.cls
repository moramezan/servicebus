public class ChainStepExtensionConfigure {
    
    private ChainStep__c chainStep;
    
    public ChainStepExtensionConfigure(ApexPages.StandardController controller) {
        //workaround for a bug: http://boards.developerforce.com/t5/forums/forumtopicprintpage/board-id/apex/message-id/45967
        if (!Test.isRunningTest()) controller.addFields(new List<String>{SObjectType.ChainStep__c.fields.Configuration__c.Name});
        this.chainStep = (ChainStep__c)controller.getRecord();
    }
    
    public PageReference initConfig() {
        if (null == this.chainStep.Configuration__c) {
            //process not configurable, go back
            return new ApexPages.StandardController(this.chainStep).view();
        } else {
            //real config exists, show edit page
            return new PageReference('/' + this.chainStep.Configuration__c + '/e?retURL=' + chainStep.Id);
        }
        
        //return config
        return new PageReference('/' + this.chainStep.Configuration__c + '/e?retURL=' + chainStep.Id);
    }
    
}