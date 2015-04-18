public with sharing class SequenceBuilderExtension {
    
    ApexPages.StandardController controller;
    SequenceModel model;
    
    public SequenceBuilderExtension(ApexPages.StandardController controller) {
        if (!Test.isRunningTest()) controller.addFields(new List<String>{'Name'});
        this.controller = controller;
        
        Sequence__c sequence = (Sequence__c)controller.getRecord();
        this.model = SequenceModel.fromName(sequence.Name);
        this.countRoutedMessages();
    }
    
    public Integer RoutedMessages {get; set;}
    
    /**
     * #768 this is used to indicate there is work processing
     * by displaying a twirly alongside the count of messages
     * that are flowing through this sequence.
     */
    public void countRoutedMessages() {
        Sequence__c sequence = [
            SELECT Id, Name
            FROM Sequence__c
            WHERE Id = :this.controller.getId()
        ];
        
        Integer count = [
            SELECT COUNT()
            FROM Message__c
            WHERE Step__c LIKE :sequence.Name + '#%'
            AND Status__c != 'Completed'
            AND Exception__c = null
        ];
        
        this.RoutedMessages = count;
    }
    
    /**
     * If we don't have an OAuthSetting__c with an AccessToken__c this
     * quickly sends us through the dance to get that set up correctly.
     */
    public PageReference initConfigure() {
        PageReference retURL = ApexPages.currentPage();
        return ConfigureController.doDanceIfNeeded(retURL);
    }
    
    static public List<ProcessModel> findProcesses() {
        List<ApexClass> apexClasses = [
            SELECT Id, Name, NamespacePrefix
            FROM ApexClass
            ORDER BY Name ASC
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        List<String> fullyQualifiedClassNames = new List<String>();
        for (ApexClass apexClass : apexClasses) {
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            if (reflector == null) continue; //eg private classes
            String fullyQualifiedClassName = reflector.getName();
            
            Type meta = Type.forName(fullyQualifiedClassName + '.' + 'ESB');
            if (meta == null) meta = Type.forName(fullyQualifiedClassName + 'ESB');
            if (meta != null) fullyQualifiedClassNames.add(fullyQualifiedClassName);
        }
        
        List<ProcessModel> processes = new List<ProcessModel>();
        for (String fullyQualifiedClassName : fullyQualifiedClassNames) {
            ProcessModel process = ProcessModel.fromFqcn(fullyQualifiedClassName);
            if (process == null) continue; //don't discover ProcessModel.ESB
            processes.add(process);
        }
        
        return processes;
    }
    
    public String getProcesses() {
        List<ProcessModel> processes = findProcesses();
        return Json.serializePretty(processes);
    }
    
    public String getSteps() {
        List<Step__c> steps = this.model.fetchSteps();
        return Json.serializePretty(steps);
    }
    
    @RemoteAction static public void refreshStepConfigName(Id configId) {
        Step__c step = [SELECT Id FROM Step__c WHERE ConfigId__c = :configId];
        String objectType = configId.getSObjectType().getDescribe().getName();
        SObject config = Database.query('SELECT Id, Name FROM ' + objectType + ' WHERE Id = :configId');
        String configName = (String)config.get('Name');
        step.ConfigName__c = configName.abbreviate(SObjectType.Step__c.Fields.ConfigName__c.Length);
        update step;
    }
    
    @RemoteAction static public List<Step__c> fetchSteps(String sequenceName) {
        SequenceModel model = SequenceModel.fromName(sequenceName);
        model.terminate();
        return model.fetchSteps();
    }
    
    @RemoteAction static public Step__c appendStep(String sequenceName, String fullyQualifiedClassName) {
        SequenceModel model = SequenceModel.fromName(sequenceName);
        Step__c step = model.appendStep(fullyQualifiedClassName);
        return step;
    }
    
    @RemoteAction static public void moveStepBefore(Id stepId, Id beforeStepId) {
        StepModel.fromId(stepId).moveBefore(beforeStepId);
    }
    
    @RemoteAction static public void moveStepAfter(Id stepId, Id afterStepId) {
        StepModel.fromId(stepId).moveAfter(afterStepId);
    }
    
    @RemoteAction static public void destroySteps(List<Step__c> steps) {
        //requery first step to get sequence id, since it is not transmitted
        Step__c step = (Step__c)ApexDomain.getById(steps[0].Id);
        SequenceModel model = SequenceModel.fromName(step.SequenceName__c);
        model.destroySteps(new Map<Id,Step__c>(steps).keySet());
    }
    
    @RemoteAction static public String enqueue(String sequenceName) {
        Job j = new Job(sequenceName, UserInfo.getOrganizationId());
        System.enqueueJob(j);
        return sequenceName;
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
                SELECT Id, Name, FullyQualifiedClassName__c
                FROM Step__c
                WHERE SequenceName__c = :sequence.Name
                ORDER BY Position__c ASC
            ];
            
            for (Step__c step : steps) {
                if (step.FullyQualifiedClassName__c == Terminate.class.getName()) {
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
            if ((steps.size() > 0) ? (steps[steps.size() - 1].FullyQualifiedClassName__c != Terminate.class.getName()) : false) {
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
            SELECT Id, Name
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Map<Id,SObject> publishConfigIdToPublishConfig = ApexDomain.mapAll(PublishConfig__c.SObjectType);
        List<SubscribeConfig__c> SubscribeConfigs = ApexDomain.listAll(SubscribeConfig__c.SObjectType);
        Map<Id,SObject> eventTypeIdToEventType = ApexDomain.mapAll(EventType__c.SObjectType);
        
        for (Sequence__c sequence : sequences) {
            Boolean containsPublish = false;
            
            List<Step__c> steps = [
                SELECT Id, Name, FullyQualifiedClassName__c, ConfigId__c
                FROM Step__c
                WHERE SequenceName__c = :sequence.Name
                ORDER BY Position__c ASC
            ];
            
            for (Step__c step : steps) if (step.FullyQualifiedClassName__c == Publish.class.getName()) containsPublish = true;
            
            //no publish steps to check
            if (!containsPublish) continue;
            
            for (Step__c step : steps) {
                //skip non-publish steps
                if (step.FullyQualifiedClassName__c != Publish.class.getName()) continue;
                
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
            SELECT Id, Name
            FROM Sequence__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        Map<Id,SObject> subscribeConfigIdToSubscribeConfig = ApexDomain.mapAll(SubscribeConfig__c.SObjectType);
        List<PublishConfig__c> publishConfigs = ApexDomain.listAll(PublishConfig__c.SObjectType);
        Map<Id,SObject> eventTypeIdToEventType = ApexDomain.mapAll(EventType__c.SObjectType);
        
        for (Sequence__c sequence : sequences) {
            List<Step__c> steps = [
                SELECT Id, Name, FullyQualifiedClassName__c, ConfigId__c
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
                if (step.FullyQualifiedClassName__c == Subscribe.class.getName()) {
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