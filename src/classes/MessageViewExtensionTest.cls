@IsTest class MessageViewExtensionTest {
    
    static testmethod void coverShowService() {
        //arrange record
        Message__c message = new Message__c(Event__c = '{"Route":"TerminateService"}');
        insert message;
        
        //act
        Test.setCurrentPage(new PageReference('/?mid=' + message.Id));
        ApexPages.StandardController controller = new ApexPages.StandardController(new Message__c());
        MessageViewExtension extension = new MessageViewExtension(controller);
        PageReference redirect = extension.doInit();
        extension.showService();

        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
        System.assert(!ApexPages.hasMessages());
    }
    
    static testmethod void coverShowData() {
        //arrange record
        Message__c message = new Message__c(Event__c = '{}');
        insert message;
        
        //act
        Test.setCurrentPage(new PageReference('/?mid=' + message.Id));
        ApexPages.StandardController controller = new ApexPages.StandardController(new Message__c());
        MessageViewExtension extension = new MessageViewExtension(controller);
        PageReference redirect = extension.doInit();
        extension.showData();
        
        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
        System.assert(ApexPages.hasMessages());
    }
    
    static testmethod void coverRestart() {
        //arrange record
        Message__c message = new Message__c(Event__c = '{}');
        insert message;
        
        //act
        Test.setCurrentPage(new PageReference('/?mid=' + message.Id));
        ApexPages.StandardController controller = new ApexPages.StandardController(new Message__c());
        MessageViewExtension extension = new MessageViewExtension(controller);
        PageReference redirect = extension.doInit();
        extension.getRestart();
        
        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
        System.assert(!ApexPages.hasMessages());
    }
}