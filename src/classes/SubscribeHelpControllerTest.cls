@IsTest public class SubscribeHelpControllerTest {
    
    static testmethod void callingGetHealthReturnsExpectedListContaningStatusEqWarning() {
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceA = new Sequence__c(Name = 'SequenceA');
        insert sequenceA;
        
        // Sequence A - Warning : Ok but event Not published
        Step__c stepA1 = StepObject.generateOne(sequenceA.Id, subscribeProcess.Id);
        Step__c stepA2 = StepObject.generateOne(sequenceA.Id, wiretapProcess.Id);

        // Event
        EventType__c eventNotPublished = new EventType__c(
            Name = 'an-event-not-published'
        );
        insert eventNotPublished;
       
        // Config A1
        Id configurationIdA1 = ((Step__c)SalesforceObject.getById(stepA1.Id)).ConfigurationId__c;
        SubscribeConfiguration__c subscribeConfigurationA1 = (SubscribeConfiguration__c)SalesforceObject.getById(configurationIdA1);
        subscribeConfigurationA1.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationA1;
 
 
        // Act :
        SubscribeHelpController controller = new SubscribeHelpController();
        controller.findProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedWarningCount = 1;
        Integer actualWarningCount = messages.size();
        System.assertEquals(expectedWarningCount, actualWarningCount);
        
        String actualDescription = sequenceA.Id;
        String expectedDescription = 'No publisher is configured to publish event';
        System.assert(messages[0].getSummary().contains(actualDescription));
        System.assert(messages[0].getSummary().contains(expectedDescription));
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNotFirst() {
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : Subscribe Not first Step
        Step__c stepB1 = StepObject.generateOne(sequenceB.Id, wiretapProcess.Id);
        Step__c stepB2 = StepObject.generateOne(sequenceB.Id, subscribeProcess.Id);
        
        // Act :
        SubscribeHelpController controller = new SubscribeHelpController();
        controller.findProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualSequenceSubscribeNotLastStep = sequenceB.Id;
        String expectedSequenceSubscribeNotLastStep = 'Subscribe process not first step of sequence';
        System.assert(messages[0].getSummary().contains(expectedSequenceSubscribeNotLastStep));
        System.assert(messages[0].getSummary().contains(actualSequenceSubscribeNotLastStep));
    }
    
    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorGtOne() {
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        
        //arrange sequence
        Sequence__c sequenceC = new Sequence__c(Name = 'SequenceC');
        insert sequenceC;
        
        // Sequence C - Problem : Subscribe Step Occurs more than once
        Step__c stepC1 = StepObject.generateOne(sequenceC.Id, subscribeProcess.Id);
        Step__c stepC2 = StepObject.generateOne(sequenceC.Id, subscribeProcess.Id);
            
        // Event
        EventType__c eventNotPublished = new EventType__c(
            Name = 'an-event-not-published'
        );
        insert eventNotPublished;

        // Config C1
        Id configurationIdC1 = ((Step__c)SalesforceObject.getById(stepC1.Id)).ConfigurationId__c;
        SubscribeConfiguration__c subscribeConfigurationC1 = (SubscribeConfiguration__c)SalesforceObject.getById(configurationIdC1);
        subscribeConfigurationC1.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationC1;

        // Config C2
        Id configurationIdC2 = ((Step__c)SalesforceObject.getById(stepC2.Id)).ConfigurationId__c;
        SubscribeConfiguration__c subscribeConfigurationC2 = (SubscribeConfiguration__c)SalesforceObject.getById(configurationIdC2);
        subscribeConfigurationC2.EventType__c = eventNotPublished.Id;
        update subscribeConfigurationC2;
        
        // Act :
        SubscribeHelpController controller = new SubscribeHelpController();
        controller.findProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);

        String actualDescription = sequenceC.Id;
        String expectedDescription = 'Subscribe appears more than once in sequence';
        System.assert(messages[0].getSummary().contains(expectedDescription));
        System.assert(messages[0].getSummary().contains(actualDescription));
    }

    static testmethod void callingGetHealthReturnsExpectedListContainingStatusEqErrorNoEventConfig() {
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        
        //arrange sequence
        Sequence__c sequenceB = new Sequence__c(Name = 'SequenceB');
        insert sequenceB;
        
        // Sequence B - Problem : No Configuration
        Step__c stepB1 = StepObject.generateOne(sequenceB.Id, subscribeProcess.Id);
        Step__c stepB2 = StepObject.generateOne(sequenceB.Id, wiretapProcess.Id);

        // Act :
        SubscribeHelpController controller = new SubscribeHelpController();
        controller.findProblems();
        
        // Assemble :
        List<ApexPages.Message> messages = ApexPages.getMessages();
        
        // Assert :
        Integer expectedErrorCount = 1;
        Integer actualErrorCount = messages.size();
        System.assertEquals(expectedErrorCount, actualErrorCount);
        
        String actualDescription = sequenceB.Id;
        String expectedDescription = 'No event type defined on Subscribe Configuration';
        System.assert(messages[0].getSummary().contains(expectedDescription));
        System.assert(messages[0].getSummary().contains(actualDescription));
    }

}