public with sharing class SequenceBuilderExtension {
    
    ApexPages.StandardController controller;
    
    public SequenceBuilderExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    /**
     * If we don't have an OAuthSetting__c with an AccessToken__c this
     * quickly sends us through the dance to get that set up correctly.
     */
    public PageReference initConfigure() {
        PageReference retURL = ApexPages.currentPage();
        return ConfigureController.doDanceIfNeeded(retURL);
    }
    
    public String getProcesses() {
        List<Process__c> procs = ApexDomain.listAll(Process__c.SObjectType);
        return Json.serializePretty(procs);
    }
    
    public String getSteps() {
        SequenceModel sequence = new SequenceModel((Sequence__c)this.controller.getRecord());
        List<Step__c> steps = sequence.fetchSteps().getRecords();
        return Json.serializePretty(steps);
    }
    
    @RemoteAction static public List<Step__c> fetchSteps(Id sequenceId) {
        SequenceModel sequence = new SequenceModel(new Sequence__c(Id = sequenceId));
        sequence.terminate();
        return sequence.fetchSteps().getRecords();
    }
    
    @RemoteAction static public Step__c appendStep(Id sequenceId, Id processId) {
        SequenceModel sequence = new SequenceModel(new Sequence__c(Id = sequenceId));
        StepModel step = sequence.appendStep(processId);
        return (Step__c)step.getRecord();
    }
    
    @RemoteAction static public void moveStepBefore(Id stepId, Id beforeStepId) {
        Step__c step = (Step__c)ApexDomain.getById(stepId);
        new StepModel(step).moveBefore(beforeStepId);
    }
    
    @RemoteAction static public void moveStepAfter(Id stepId, Id afterStepId) {
        Step__c step = (Step__c)ApexDomain.getById(stepId);
        new StepModel(step).moveAfter(afterStepId);
    }
    
    @RemoteAction static public void destroySteps(List<Step__c> steps) {
        //requery first step to get sequence id, since it is not transmitted
        Step__c step = (Step__c)ApexDomain.getById(steps[0].Id);
        SequenceModel sequence = new SequenceModel(new Sequence__c(Id = step.Sequence__c));
        sequence.destroySteps(new Map<Id,Step__c>(steps).keySet());
    }
    
    @RemoteAction static public String enqueue(Id sequenceId) {
        Sequence__c sequence = (Sequence__c)ApexDomain.getById(sequenceId);
        System.enqueueJob(new Job(sequence.Name, UserInfo.getUserId()));
        return sequence.Name;
    }
    
    /**
     * Health check stuff
     */
    public PageReference findTerminateProblems() {
        try {
        List<Sequence__c> sequences = [
            SELECT Id, Name,
            (SELECT Id, Name, Process__c FROM Steps__r ORDER BY Position__c ASC) steps
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Process__c terminateProcess = [
            SELECT Id
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :Terminate.class.getName()
        ];
        
        // Error conditions:
        // * Sequence with no Terminate (error)
        // * Sequence with more than one Terminate (error)
        // * Terminate that's not at the end (error)
        for (Sequence__c sequence : sequences) {
            Integer terminateCount = 0;
            
            for (Step__c step : sequence.Steps__r) {
                if (step.Process__c == terminateProcess.Id) {
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
            if ((sequence.Steps__r.size() > 0) ? (sequence.Steps__r[sequence.Steps__r.size() - 1].Process__c != terminateProcess.Id) : false) {
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
            return new PageReference('/apex/Csh?topic=ProcessTerminate');
        }
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public PageReference findPublishProblems() {
        try {
        List<Sequence__c> sequences = [
            SELECT Id, Name,
            (SELECT id, Name, Process__c, ConfigId__c FROM Steps__r ORDER BY Position__c ASC)
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Process__c publishProcess = [
            SELECT Id
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :Publish.class.getName()
        ];
        
        Map<Id,SObject> publishConfigIdToPublishConfig = ApexDomain.mapAll(PublishConfig__c.SObjectType);
        List<SubscribeConfig__c> SubscribeConfigs = ApexDomain.listAll(SubscribeConfig__c.SObjectType);
        Map<Id,SObject> eventTypeIdToEventType = ApexDomain.mapAll(EventType__c.SObjectType);
        
        for (Sequence__c sequence : sequences) {
            Boolean containsPublish = false;
            for (Step__c step : sequence.Steps__r) if (step.Process__c == PublishProcess.Id) containsPublish = true;
            
            //no publish steps to check
            if (!containsPublish) continue;
            
            for (Step__c step : sequence.Steps__r) {
                //skip non-publish steps
                if (step.Process__c != publishProcess.Id) continue;
                
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
            return new PageReference('/apex/Csh?topic=ProcessPublishSubscribe');
        }
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public PageReference findSubscribeProblems() {
        try {
        List<Sequence__c> sequences = [
            SELECT Id, Name,
            (SELECT Id, Name, Process__c, ConfigId__c FROM Steps__r ORDER BY Position__c ASC) steps
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Process__c subscribeProcess = [
            SELECT Id
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :Subscribe.class.getName()
        ];
        
        Map<Id,SObject> subscribeConfigIdToSubscribeConfig = ApexDomain.mapAll(SubscribeConfig__c.SObjectType);
        List<PublishConfig__c> publishConfigs = ApexDomain.listAll(PublishConfig__c.SObjectType);
        Map<Id,SObject> eventTypeIdToEventType = ApexDomain.mapAll(EventType__c.SObjectType);
        
        for (Sequence__c sequence : sequences) {
            List<Step__c> steps = sequence.Steps__r;
            Integer subscribeOccurs = 0;
            Integer count = 1;
            Boolean subscribeFirst = false;
            Id stepId = null;
            Id subscribeConfigId = null;
            
            for (Step__c step : steps) {
                if (step.Process__c == SubscribeProcess.Id) {
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
            return new PageReference('/apex/Csh?topic=ProcessPublishSubscribe');
        }
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
}