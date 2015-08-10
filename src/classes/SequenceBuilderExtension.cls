public with sharing class SequenceBuilderExtension {
    
    private ApexPages.StandardController controller;
    private SequenceModel model;
    
    public SequenceBuilderExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = SequenceModel.fromId(controller.getId());
        this.countRoutedMessages();
    }
    
    public Integer RoutedMessages {get; set;}
    
    /**
     * #768 this is used to indicate there is work processing
     * by displaying a twirly alongside the count of messages
     * that are flowing through this sequence.
     */
    public void countRoutedMessages() {
        this.RoutedMessages = this.model.countRoutedMessages();
    }
    
    /**
     * #930 this detects "Configure Not Clicked"
     * situation and sends user to configure page.
     */
    public PageReference doRedirect() {
        if (OAuthSetting__c.getOrgDefaults().RunningUserId__c == null) {
            //failure, someone better configure the package
            return Page.Configure;
        } else {
            //success, just display the sequence builder
            return null;
        }
    }
    
    public String getTerminateApexClassName() {
        return Terminate.class.getName();
    }
    
    public String getProcesses() {
        //don't discover our ESB summary class template
        List<ApexClass> apexClasses = [SELECT Id FROM ApexClass WHERE Name != 'ApexClassModel'];
        ApexClassSetModel model = new ApexClassSetModel(apexClasses);
        model.discoverProcesses();
        
        List<Map<String,Object>> processes = model.toDtos();
        return Json.serializePretty(processes);
    }
    
    public String getSteps() {
        List<Map<String,Object>> stepDtos = this.model.stepSetModel().toDtos();
        return Json.serializePretty(stepDtos);
    }
    
    @RemoteAction static public void cacheConfigName(Id stepId) {
        StepModel.fromId(stepId).cacheConfigName();
    }
    
    @RemoteAction static public List<Map<String,Object>> fetchSteps(Id sequenceId) {
        SequenceModel model = SequenceModel.fromId(sequenceId);
        model.terminateIfNeeded();
        return model.stepSetModel().toDtos();
    }
    
    @RemoteAction static public Step__c appendStep(Id sequenceId, String apexClassId) {
        SequenceModel model = SequenceModel.fromId(sequenceId);
        return model.appendStep(apexClassId);
    }
    
    @RemoteAction static public void moveStepBefore(String stepName, String beforeStepName) {
        StepModel.fromName(stepName).moveBefore(beforeStepName);
    }
    
    @RemoteAction static public void moveStepAfter(String stepName, String afterStepName) {
        StepModel.fromName(stepName).moveAfter(afterStepName);
    }
    
    @RemoteAction static public void destroyStep(Id sequenceId, String stepName) {
        SequenceModel model = SequenceModel.fromId(sequenceId);
        model.destroyStep(stepName);
    }
    
    @RemoteAction static public Id enqueue(Id sequenceId) {
        SequenceModel model = SequenceModel.fromId(sequenceId);
        return model.enqueueTestMessage();
    }
    
    /**
     * Health check stuff
     */
    public PageReference findTerminateProblems() {
        try {
        List<Sequence__c> sequences = [
            SELECT Id, Name
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        // Error conditions:
        // * Sequence with no Terminate (error)
        // * Sequence with more than one Terminate (error)
        // * Terminate that's not at the end (error)
        for (Sequence__c sequence : sequences) {
            Integer terminateCount = 0;
            
            List<Step__c> steps = [
                SELECT Id, Name, ApexClassName__c
                FROM Step__c
                WHERE SequenceName__c = :sequence.Name
                ORDER BY Position__c ASC
            ];
            
            for (Step__c step : steps) {
                if (step.ApexClassName__c == Terminate.class.getName()) {
                    terminateCount++;
                }
            }
            
            //no terminate error
            if (terminateCount == 0) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'No Terminate found in sequence ' + sequence.Id
                ));
                continue;
            }
            
            //terminate not at end error
            if ((steps.size() > 0) ? (steps[steps.size() - 1].ApexClassName__c != Terminate.class.getName()) : false) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'Terminate process not present at end of sequence ' + sequence.Id
                ));
                continue;
            }
            
            //greater than one terminate error
            if (terminateCount > 1) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'More than one Terminate found in sequence ' + sequence.Id
                ));
                continue;
            }
        }
        
        if (ApexPages.hasMessages()) {
            //show problems
            return null;
        } else {
            //redirect to help
            return new PageReference('/apex/ContextSensitiveHelp?topic=ProcessTerminate');
        }
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public PageReference findPublishProblems() {
        try {
        List<Sequence__c> sequences = [
            SELECT Id, Name
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Map<Id,SObject> publishConfigIdToPublishConfig = new Map<Id,SObject>([SELECT Id, EventType__c FROM PublishConfig__c]);
        List<SubscribeConfig__c> SubscribeConfigs = [SELECT Id, EventType__c FROM SubscribeConfig__c];
        
        for (Sequence__c sequence : sequences) {
            Boolean containsPublish = false;
            
            List<Step__c> steps = [
                SELECT Id, Name, ApexClassName__c, ConfigId__c
                FROM Step__c
                WHERE SequenceName__c = :sequence.Name
                ORDER BY Position__c ASC
            ];
            
            for (Step__c step : steps) if (step.ApexClassName__c == Publish.class.getName()) containsPublish = true;
            
            //no publish steps to check
            if (!containsPublish) continue;
            
            for (Step__c step : steps) {
                //skip non-publish steps
                if (step.ApexClassName__c != Publish.class.getName()) continue;
                
                Id stepId = step.Id;
                Id publishConfigId = (Id) step.ConfigId__c; // cast from string to Id
                
                PublishConfig__c publishConfig;
                Id eventTypeId;
                publishConfig = (PublishConfig__c)publishConfigIdToPublishConfig.get(publishConfigId);
                eventTypeId = publishConfig.EventType__c;
                
                if (eventTypeId == null) {
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.WARNING,
                        'No event type has been configured on ' + publishConfigId
                    ));
                    continue;
                }
                
                Boolean subscriberFound = false;
                for (SubscribeConfig__c SubscribeConfig : SubscribeConfigs) {
                    if (SubscribeConfig.EventType__c == eventTypeId) {
                        subscriberFound = true;
                    }
                }
                
                if (!subscriberFound) {
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.WARNING,
                        'There are no subscribers listening to the event on ' + publishConfigId
                    ));
                }
            }
        }
        
        if (ApexPages.hasMessages()) {
            //show problems
            return null;
        } else {
            //redirect to help
            return new PageReference('/apex/ContextSensitiveHelp?topic=ProcessPublishSubscribe');
        }
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public PageReference findSubscribeProblems() {
        try {
        List<Sequence__c> sequences = [
            SELECT Id, Name
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Map<Id,SObject> subscribeConfigIdToSubscribeConfig = new Map<Id,SObject>([SELECT Id, EventType__c FROM SubscribeConfig__c]);
        List<PublishConfig__c> publishConfigs = [SELECT Id, EventType__c FROM PublishConfig__c];
        
        for (Sequence__c sequence : sequences) {
            List<Step__c> steps = [
                SELECT Id, Name, ApexClassName__c, ConfigId__c
                FROM Step__c
                WHERE SequenceName__c = :sequence.Name
                ORDER BY Position__c ASC
            ];
            
            Integer subscribeOccurs = 0;
            Integer count = 1;
            Boolean subscribeFirst = false;
            Id stepId = null;
            Id subscribeConfigId = null;
            
            for (Step__c step : steps) {
                if (step.ApexClassName__c == Subscribe.class.getName()) {
                    subscribeOccurs++;
                    subscribeConfigId = (Id) step.ConfigId__c; // cast from string to Id
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
            
            SubscribeConfig__c subscribeConfig = (SubscribeConfig__c)subscribeConfigIdToSubscribeConfig.get(subscribeConfigId);
            if (subscribeConfig.EventType__c == null) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'No event type defined on Subscribe Config ' + sequence.Id
                ));
                continue;
            }
            
            Boolean publisherFound = false;
            for (PublishConfig__c  publishConfig : publishConfigs) {
                if (subscribeConfig.EventType__c != null && publishConfig.EventType__c == subscribeConfig.EventType__c) publisherFound = true;
            }
            
            if (!publisherFound) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'No publisher is configured to publish event ' + sequence.Id
                ));
                continue;
            }
        }
        
        if (ApexPages.hasMessages()) {
            //show problems
            return null;
        } else {
            //redirect to help
            return new PageReference('/apex/ContextSensitiveHelp?topic=ProcessPublishSubscribe');
        }
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
}