@IsTest public class MessageDataExtensionTest {

    static testmethod void testRedirect() {
        //arrange message
        Map<String,Object> parameters = new Map<String,Object>{'esb__Id' => UserInfo.getUserId()};
        List<Message__c> messages = new Job(parameters).persist();
        
        ApexPages.StandardController controller = new ApexPages.StandardController(messages[0]);
        MessageDataExtension extension = new MessageDataExtension(controller);
        
        //act
        PageReference redirect = extension.doRedirect();
        
        //assert
        String expectedUrl = String.valueOf(UserInfo.getUserId()).left(15);
        String actualUrl = redirect.getUrl();
        System.assert(actualUrl.contains(expectedUrl));
    
    }

}