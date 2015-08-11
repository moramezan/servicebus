@IsTest public class MessageKillExtensionTest {

    static testmethod void coverCode() {
        //arrange controller and extension
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Message__c>());
        MessageKillExtension extension = new MessageKillExtension(controller);
        
        //act
        extension.doKill();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }

}