@IsTest public class PublishHelpControllerTest {
    
    static testmethod void callingGetHealthReturnsExpectedListContaningStatusEqWarning() {
        // Arrange :
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        
        //arrange proceses
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        // Sequence A - Warning : Ok but event Not Subscribed
        Step__c stepA1 = StepObject.generateOne(sequenceA.Id, publishProcess.Id);
        Step__c stepA2 = StepObject.generateOne(sequenceA.Id, wiretapProcess.Id);
        
        // Event
        EventType__c eventTypeNotSubscribed = new EventType__c(
            Name = 'an-event-not-Subscribed'
        );
        insert eventTypeNotSubscribed;
        
        // Config A1
        Id configurationIdA1 = ((Step__c)SalesforceObject.getById(stepA1.Id)).ConfigurationId__c;
        
        PublishConfiguration__c PublishConfigurationA1 = (PublishConfiguration__c)SalesforceObject.getById(configurationIdA1);
        
        PublishConfigurationA1.EventType__c = eventTypeNotSubscribed.Id;
        update PublishConfigurationA1;
        
        // Act :
        PublishHelpController controller = new PublishHelpController();
        controller.findProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedWarningCount = 1;
        Integer actualWarningCount = messages.size();
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String expectedDescription = 'There are no subscribers listening to the event';
        String actualDescription = messages[0].getSummary();
        System.assert(actualDescription.contains(expectedDescription));
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfig() {
        // Arrange :
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        //arrange processes
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        // Sequence B - Problem : No Configuration
        Step__c stepB1 = StepObject.generateOne(sequenceB.Id, publishProcess.Id);
        Step__c stepB2 = StepObject.generateOne(sequenceB.Id, wiretapProcess.Id);
        
        // Act :
        PublishHelpController controller = new PublishHelpController();
        controller.findProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);
        
        String expectedDescription = 'No event type has been configured';
        String actualDescription = messages[0].getSummary();
        System.assert(actualDescription.contains(expectedDescription), messages[0]);
    }
    
}