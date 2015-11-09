@IsTest class MessageApexClassExtensionTest {
    
    static testmethod void coverCode() {
        //arrange record
        Message__c message = new Message__c();
        insert message;
        
        //act
        ApexPages.StandardController controller = new ApexPages.StandardController(message);
        MessageApexClassExtension extension = new MessageApexClassExtension(controller);
        extension.showApexClass();
        
        //assert
        System.assert(ApexPages.hasMessages());
    }
    
}