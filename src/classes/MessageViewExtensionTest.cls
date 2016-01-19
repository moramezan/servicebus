@IsTest class MessageViewExtensionTest {
    
    static testmethod void coverShowService() {
        //arrange record
        Message__c message = new Message__c(Event__c = '{"Route":"TerminateService"}');
        insert message;
        
        //arrange page
        Test.setCurrentPage(new PageReference('/?mid=' + message.Id));
        ApexPages.StandardController controller = new ApexPages.StandardController(new Message__c());
        MessageViewExtension extension = new MessageViewExtension(controller);
        
        //act
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TokenResponse());
        PageReference redirect = extension.doInit();
        extension.showService();
        Test.stopTest();

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
        
        //arrange page
        Test.setCurrentPage(new PageReference('/?mid=' + message.Id));
        ApexPages.StandardController controller = new ApexPages.StandardController(new Message__c());
        MessageViewExtension extension = new MessageViewExtension(controller);
        
        //act
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TokenResponse());
        PageReference redirect = extension.doInit();
        extension.getRestart();
        Test.stopTest();
        
        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
        System.assert(!ApexPages.hasMessages());
    }
    
    @TestVisible class TokenResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            ConfigureController.Token token = new ConfigureController.Token();
            token.refresh_token = 'rrrrr';
            token.access_token = 'aaaaa';
            
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(Json.serialize(token));
            return response;
        }
    }
}