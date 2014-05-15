public with sharing class PublishHelpController {
    
    public void findProblems() {
        List<Sequence__c> sequences = [
            SELECT Id, Name,
            (SELECT id, Name, Process__c, ConfigurationId__c FROM Steps__r ORDER BY Position__c ASC)
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Process__c publishProcess = [
            SELECT Id
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :Publish.class.getName()
        ];
        
        Map<Id,SObject> publishConfigurationIdToPublishConfiguration = SalesforceObjectSet.mapAll(PublishConfiguration__c.SObjectType);
        List<SubscribeConfiguration__c> SubscribeConfigurations = SalesforceObjectSet.listAll(SubscribeConfiguration__c.SObjectType);
        Map<Id,SObject> eventTypeIdToEventType = SalesforceObjectSet.mapAll(EventType__c.SObjectType);
        
        for (Sequence__c sequence : sequences) {
            Boolean containsPublish = false;
            for (Step__c step : sequence.Steps__r) if (step.Process__c == PublishProcess.Id) containsPublish = true;
            
            //no publish steps to check
            if (!containsPublish) continue;
            
            for (Step__c step : sequence.Steps__r) {
                //skip non-publish steps
                if (step.Process__c != publishProcess.Id) continue;
                
                Id stepId = step.Id;
                Id publishConfigurationId = (Id) step.ConfigurationId__c; // cast from string to Id
                
                PublishConfiguration__c publishConfiguration;
                Id eventTypeId;
                publishConfiguration = (PublishConfiguration__c)publishConfigurationIdToPublishConfiguration.get(publishConfigurationId);
                eventTypeId = publishConfiguration.EventType__c;
                
                if (eventTypeId == null) {
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.WARNING,
                        'No event type has been configured on ' + publishConfigurationId
                    ));
                    continue;
                }
                
                Boolean subscriberFound = false;
                for (SubscribeConfiguration__c SubscribeConfiguration : SubscribeConfigurations) {
                    if (SubscribeConfiguration.EventType__c == eventTypeId) {
                        subscriberFound = true;
                    }
                }
                
                if (!subscriberFound) {
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.WARNING,
                        'There are no subscribers listening to the event on ' + publishConfigurationId
                    ));
                }
            }
        }
    }
    
}