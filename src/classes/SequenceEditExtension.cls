public with sharing class SequenceEditExtension {
    
    ApexPages.StandardController controller;
    Sequence__c sequence;
    SequenceModel model;
    
    public SequenceEditExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.sequence = (Sequence__c)controller.getRecord();
        this.model = SequenceModel.fromId(controller.getId());
        this.countRoutedMessages();
    }
    
    static public Integer getDraftVersion() {
        return SequenceSetModel.draftVersion();
    }
    
    public Integer RoutedMessages {get; set;}
    
    /**
     * #768 this is used to indicate there is work ongoing
     * by displaying a twirly alongside the count of messages
     * that are flowing through this sequence.
     */
    public void countRoutedMessages() {
        this.RoutedMessages = this.model.countRoutedMessages();
    }
    
    //#173 terminate sequence on read
    static SequenceModel TerminateModel;
    public class DoDml {
        public DoDml() {
            TerminateModel.terminateIfNeeded();
        }
    }
    
    /**
     * #930 this detects "Configure Not Clicked"
     * situation and sends user to configure page.
     */
    public PageReference doRedirect() {
        //#173 terminate sequence on read
        TerminateModel = SequenceModel.fromId(this.controller.getId());
        Type.forName(DoDml.class.getName()).newInstance();
        PageReference redirect;
        
        //configure if needed
        redirect = ConfigureController.ConfigureIfNeeded(ApexPages.currentPage());
        if (redirect != null) return redirect;
        
        //discover if needed
        redirect = ApexClassDiscoverExtension.DiscoverIfNeeded(ApexPages.currentPage());
        if (redirect != null) return redirect;
        
        return null;
    }
    
    public String getTerminateApexClassName() {
        return TerminateService.class.getName();
    }
    
    /**
     * The application is snappier when all Sequence Steps are already loaded when the page
     * displays, instead of fetching them for the first time with a RemoteAction call.
     *
     * A freshly created Sequence lacks a terminate! But since the Page Action invokes
     * sequence.terminate(), the Terminate Step should exist before the page is rendered.
     */
    public String getSteps() {
        return Json.serialize(this.model.stepDtos());
    }
    
    public String getServices() {
        return Json.serialize(ApexClassSetModel.loadCache().values());
    }
    
    @RemoteAction static public void persistConfigNameOnStep(Id stepId) {
        StepModel.fromId(stepId).persistConfigNameOnStep();
    }
    
    @RemoteAction static public List<Map<String,Object>> fetchSteps(Id sequenceId) {
        SequenceModel model = SequenceModel.fromId(sequenceId);
        return model.stepDtos();
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
                WHERE Sequence__c = :sequence.Name
                ORDER BY Position__c ASC
            ];
            
            for (Step__c step : steps) {
                if (step.ApexClassName__c == TerminateService.class.getName()) {
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
            if ((steps.size() > 0) ? (steps[steps.size() - 1].ApexClassName__c != TerminateService.class.getName()) : false) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'Terminate not present at end of sequence ' + sequence.Id
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
            return new PageReference('/apex/ContextSensitiveHelp?topic=ServiceTerminate');
        }
    }
    
    public PageReference findPublishProblems() {
        List<Sequence__c> sequences = [
            SELECT Id, Name
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Map<Id,SObject> publishConfigIdToPublishConfig = new Map<Id,SObject>([SELECT Id, EventType__c FROM PublishStepConfig__c LIMIT 10000]); //checkmarx
        List<SubscribeStepConfig__c> SubscribeConfigs = [SELECT Id, EventType__c FROM SubscribeStepConfig__c LIMIT 10000]; //checkmarx
        
        for (Sequence__c sequence : sequences) {
            Boolean containsPublish = false;
            
            List<Step__c> steps = [
                SELECT Id, Name, ApexClassName__c, ConfigId__c
                FROM Step__c
                WHERE Sequence__c = :sequence.Name
                ORDER BY Position__c ASC
            ];
            
            for (Step__c step : steps) if (step.ApexClassName__c == PublishService.class.getName()) containsPublish = true;
            
            //no publish steps to check
            if (!containsPublish) continue;
            
            for (Step__c step : steps) {
                //skip non-publish steps
                if (step.ApexClassName__c != PublishService.class.getName()) continue;
                
                Id stepId = step.Id;
                Id publishConfigId = (Id) step.ConfigId__c; // cast from string to Id
                
                PublishStepConfig__c publishConfig;
                String eventType;
                publishConfig = (PublishStepConfig__c)publishConfigIdToPublishConfig.get(publishConfigId);
                eventType = publishConfig.EventType__c;
                
                if (eventType == null) {
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.WARNING,
                        'No event type has been configured on ' + publishConfigId
                    ));
                    continue;
                }
                
                Boolean subscriberFound = false;
                for (SubscribeStepConfig__c SubscribeConfig : SubscribeConfigs) {
                    if (SubscribeConfig.EventType__c == eventType) {
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
            return new PageReference('/apex/ContextSensitiveHelp?topic=ServicePublishSubscribe');
        }
    }
    
    public PageReference findSubscribeProblems() {
        List<Sequence__c> sequences = [
            SELECT Id, Name
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Map<Id,SObject> subscribeConfigIdToSubscribeConfig = new Map<Id,SObject>([SELECT Id, EventType__c FROM SubscribeStepConfig__c LIMIT 10000]); //checkmarx
        List<PublishStepConfig__c> publishConfigs = [SELECT Id, EventType__c FROM PublishStepConfig__c LIMIT 10000]; //checkmarx
        
        for (Sequence__c sequence : sequences) {
            List<Step__c> steps = [
                SELECT Id, Name, ApexClassName__c, ConfigId__c
                FROM Step__c
                WHERE Sequence__c = :sequence.Name
                ORDER BY Position__c ASC
            ];
            
            Integer subscribeOccurs = 0;
            Integer count = 1;
            Boolean subscribeFirst = false;
            Id stepId = null;
            Id subscribeConfigId = null;
            
            for (Step__c step : steps) {
                if (step.ApexClassName__c == SubscribeService.class.getName()) {
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
                    'Subscribe not first step of sequence ' + sequence.Id
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
            
            SubscribeStepConfig__c subscribeConfig = (SubscribeStepConfig__c)subscribeConfigIdToSubscribeConfig.get(subscribeConfigId);
            if (subscribeConfig.EventType__c == null) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'No event type defined on Subscribe Config ' + sequence.Id
                ));
                continue;
            }
            
            Boolean publisherFound = false;
            for (PublishStepConfig__c  publishConfig : publishConfigs) {
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
            return new PageReference('/apex/ContextSensitiveHelp?topic=ServicePublishSubscribe');
        }
    }
}