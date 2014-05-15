public with sharing class SubscribeHelpController {
    
    public void findProblems() {
        
        List<Sequence__c> sequences = [
            SELECT Id, Name,
            (SELECT Id, Name, Process__c, ConfigurationId__c FROM Steps__r ORDER BY Position__c ASC) steps
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Process__c subscribeProcess = [
            SELECT Id
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :Subscribe.class.getName()
        ];
        
        Map<Id,SObject> subscribeConfigurationIdToSubscribeConfiguration = SalesforceObjectSet.mapAll(SubscribeConfiguration__c.SObjectType);
        List<PublishConfiguration__c> publishConfigurations = SalesforceObjectSet.listAll(PublishConfiguration__c.SObjectType);
        Map<Id,SObject> eventTypeIdToEventType = SalesforceObjectSet.mapAll(EventType__c.SObjectType);
        
        for (Sequence__c sequence : sequences) {
            List<Step__c> steps = sequence.Steps__r;
            Integer subscribeOccurs = 0;
            Integer count = 1;
            Boolean subscribeFirst = false;
            Id stepId = null;
            Id subscribeConfigurationId = null;
            
            for (Step__c step : steps) {
                if (step.Process__c == SubscribeProcess.Id) {
                    subscribeOccurs++;
                    subscribeConfigurationId = (Id) step.ConfigurationId__c; // cast from string to Id
                    if (count == 1) {
                        subscribeFirst = true;
                        stepId = step.Id;
                    }
                }
                count++;
            }
            
            //this sequence has no subscribe step
            if (subscribeOccurs == 0) continue;
            
            if (!subscribeFirst) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'Subscribe process not first step of sequence ' + sequence.Id
                ));
                continue;
            }
            
            if (subscribeOccurs > 1) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'Subscribe appears more than once in sequence ' + sequence.Id
                ));
                continue;
            }
            
            SubscribeConfiguration__c subscribeConfiguration = (SubscribeConfiguration__c)subscribeConfigurationIdToSubscribeConfiguration.get(subscribeConfigurationId);
            if (subscribeConfiguration.EventType__c == null) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'No event type defined on Subscribe Configuration ' + sequence.Id
                ));
                continue;
            }
            
            Boolean publisherFound = false;
            for (PublishConfiguration__c  publishConfiguration : publishConfigurations) {
                if (subscribeConfiguration.EventType__c != null && publishConfiguration.EventType__c == subscribeConfiguration.EventType__c) publisherFound = true;
            }
            
            if (!publisherFound) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'No publisher is configured to publish event ' + sequence.Id
                ));
                continue;
            }
        }
    }

}