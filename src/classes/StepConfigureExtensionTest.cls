@IsTest public class StepConfigureExtensionTest {
    
    static testmethod void coverCode() {
        //arrange record
        insert new Step__c(
            Name = 'Test#1',
            ApexClassName__c = Jump.class.getName()
        );
        
        //arrange controller and extension
        Step__c step = Step__c.getValues('Test#1');
        ApexPages.StandardController controller = new ApexPages.StandardController(step);
        StepConfigureExtension extension = new StepConfigureExtension(controller);
        
        //act
        PageReference redirect = extension.doRedirect();
        
        //assert
        Id expectedId = [SELECT Id FROM JumpConfig__c].Id;
        Id actualId = Step__c.getValues('Test#1').ConfigId__c;
        System.assertEquals(expectedId, actualId, 'Wrong step config id.');
    }
    
}