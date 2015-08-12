@IsTest public class MessageModelTest {
    
    //TODO
    
    static testmethod void testShowApexProcessFindsIt() {
        //arrange sequence and steps
        insert new Sequence__c(Name = 'Test');
        Step__c step = SequenceModel.fromName('Test').appendStep(Terminate.class);
        step.ApexClassId__c = [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
        update step;
        
        //arrange message
        Message__c message = new Message__c(
            Step__c = 'Test#1',
            Event__c = '{"__SequenceName":"Test","__Position":1}'
        );
        
        //act
        MessageModel model = new MessageModel(message);
        PageReference view = model.showApexProcess();
        
        //assert
        String expectedUrl = '/' + [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
        String actualUrl = view.getUrl();
        System.assert(expectedUrl.startsWith(actualUrl), 'Wrong URL.');
    }
    
}