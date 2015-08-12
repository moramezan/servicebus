@IsTest public class MessageModelTest {
    
    //TODO
    
    static testmethod void testShowApexClassFindsIt() {
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
        PageReference view = model.showApexClass();
        
        //assert
        String expectedUrl = '/' + [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
        String actualUrl = view.getUrl();
        System.assert(expectedUrl.startsWith(actualUrl), 'Wrong URL.');
    }

    public class NotValidProcess {}
    public class NotValidProcessESB extends ApexClassModel.BaseSummary {}
    
    static testmethod void throwsExceptionWhenNoToStringOverride() {

        //arrange sequence and steps
        insert new Sequence__c(Name = 'Test');
        Step__c step = SequenceModel.fromName('Test').appendStep(NotValidProcess.class);
        step.ApexClassId__c = [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
        update step;
 
            
        //arrange message
        Message__c message = new Message__c(
            Step__c = 'Test#1',
            Event__c = '{"__SequenceName":"Test","__Position":1}'
        );
  
        List<Message__c> outputMessages = new  List<Message__c>();
        
        //act
        MessageModel model = new MessageModel(message);
        model.prepareProcess();
        model.invokeExecute(outputMessages);

        
        //assert
       System.assert(model.IsFucked, 'This should have caught exception.');
         
       String expectedMessage = 'Your plugin has not extended abstract process. Please refer to the Process Developers Guide for specific guidance.';
         String actualMessage = message.Exception__c;
       System.assertEquals( expectedMessage, actualMessage, 'Wrong message.');
    }
}