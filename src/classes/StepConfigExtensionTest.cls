@IsTest class StepConfigExtensionTest {
    
    static testmethod void coverCode() {
        //arrange
        Step__c step = new Step__c(Name = '1#Test#1');
        insert step;
        ApexPages.StandardController controller = new ApexPages.StandardController(step);
        
        //act
        Test.setCurrentPage(Page.StepConfig);
        StepConfigExtension extension = new StepConfigExtension(controller);
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}