@IsTest public class MessageDataExtensionTest {

    static testmethod void testRedirect() {
        //arrange
        String parameters = Json.serialize(new Map<String,Object>{'esb__Id' => UserInfo.getUserId()});
        Message__c message = new Message__c(Parameters__c = parameters);
        insert message;
        
        ApexPages.StandardController controller = new ApexPages.StandardController(message);
        MessageDataExtension extension = new MessageDataExtension(controller);
        
        //act
        PageReference redirect = extension.doRedirect();
        
        //assert
        String expectedUrl = String.valueOf(UserInfo.getUserId()).left(15);
        String actualUrl = redirect.getUrl();
        System.assert(actualUrl.contains(expectedUrl));
    
    }

}