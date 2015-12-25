public class SequenceModel extends ApexDomain.StandardModel {
    
    public class ModelException extends Exception {}
    
    Sequence__c sequence;
    
    /**
     * Privatize constructor to force use of fromName() or fromId()
     */
    SequenceModel(Sequence__c sequence) {
        super(sequence);
        this.sequence = sequence;
    }
    
    /**
     * Given a sequence id, loads a model with all fields.
     *
     * @param sequenceId
     * @return domain model of sequence
     */
    static public SequenceModel fromId(Id sequenceId) {
        Sequence__c sequence = (Sequence__c)ApexDomain.getById(sequenceId);
        return new SequenceModel(sequence);
    }
    
    /**
     * Given a sequence name, loads a model with all fields.
     *
     * @param sequenceName
     * @return domain model of sequence
     */
    static public SequenceModel fromName(String sequenceName) {
        Sequence__c sequence = [SELECT Id FROM Sequence__c WHERE Name = :sequenceName];
        return fromId(sequence.Id);
    }
    
    /**
     * Appends one step to the end of a sequence,
     * normally it will appear after the Terminate.
     * PROD scenarios append both class name and id.
     *
     * @param reflector
     * @return the appended step
     */
    public Step__c appendStep(Id apexClassId) {
        ApexClass apexClass = [
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Id = :apexClassId
        ];
        
        Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
        Step__c step = this.appendStep(reflector);
        step.ApexClassId__c = apexClassId;
        update step;
        
        return step;
    }
    
    /**
     * Injects a test message to this sequence
     * carrying just the Organization Id.
     *
     * @return the queueable job id
     */
    public Id enqueueTestMessage() {
        
        //find draft version
        Integer version = SequenceSetModel.draftVersion();
        
        //initial position
        Integer position = 0;
        
        Enqueue.AllowRoute = true; //#999#issuecomment-133751700
        Map<String,Object> event = new Map<String,Object>{
            'Route' => version + '#' + this.Sequence.Name + '#' + position
        };
        Job j = new Job(event);
        Id jobId = System.enqueueJob(j);
        return jobId;
    }
    
    /**
     * TEST scenarios can append inner classes.
     */
    @TestVisible Step__c appendStep(Type reflector) {
        Savepoint sp = Database.setSavepoint();
        try {
            ApexClassModel model = new ApexClassModel(reflector);
            
            //find draft version
            Integer version = SequenceSetModel.draftVersion();
            if (version == null) version = 1; //first ever
            
            //last sibling position
            Integer position = Integer.valueOf([
                SELECT MAX(Position__c)
                FROM Step__c
                WHERE IsDraft__c = true
                AND Sequence__c = :this.sequence.Name
            ][0].get('expr0'));
            
            //null means first step, else next position after siblings
            if (position == null) position = 1; else position++;
            
            Step__c step = new Step__c(
                IsDraft__c = true,
                Version__c = version,
                Name = version + '#' + this.sequence.Name + '#' + position,
                Sequence__c = this.sequence.Name,
                ApexClassId__c = null, //see upstairs
                ApexTypeName__c = reflector.getName(),
                Position__c = position
            );
            
            insert step;
            return Step__c.getValues(step.Name);
        } catch (Exception e) {
            Database.rollback(sp);
            throw new ModelException('Could not append step "' + reflector + '"', e);
        }
    }
    
    /**
     * If this sequence contains no Terminate step, append one.
     * (Invoked by the user interface when viewing a Sequence for the first time)
     */
    public void terminateIfNeeded() {
        try {
            Step__c terminateStep = [
                SELECT Name
                FROM Step__c
                WHERE IsDraft__c = true
                AND Sequence__c = :this.sequence.Name
                AND ApexTypeName__c = :TerminateService.class.getName()
            ];
        } catch (QueryException e) {
            //sequence contains no terminate step
            ApexClass apexClass = [
                SELECT Id, NamespacePrefix, Name
                FROM ApexClass
                WHERE Name = 'TerminateService'
                AND NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c
            ];
            
            //TODO add namespace prefix safety
            this.appendStep(apexClass.Id);
        }
    }
    
    /**
     * Destroys a step within a sequence, including any
     * related StepConfig, and re-orders the other steps.
     *
     * @param stepName or route
     */
    public void destroyStep(String stepName) {
        Savepoint savepoint = Database.setSavepoint();
        try {
            Step__c stepToDelete = Step__c.getValues(stepName);
            
            //perform the delete, #1016 OUR steps skip recycle bin
            delete stepToDelete;
            Database.emptyRecycleBin(stepToDelete);
            
            //#1145 be safe, when deleting THEIR configs
            if (stepToDelete.ConfigId__c != null) destroyStepConfig(stepToDelete.ConfigId__c);
            
            //find the remaining steps
            List<Step__c> stepsToReorder = [
                SELECT Name
                FROM Step__c
                WHERE IsDraft__c = true
                AND Sequence__c = :this.sequence.Name
                ORDER BY Position__c ASC
            ];
            
            //custom settings not smart enough to recognize uniqueness in bulk update
            //https://developer.salesforce.com/forums/ForumsMain?id=906F00000008zF5IAI
            //so we have to make them unique first so that we can overwrite them second
            for (Step__c stepToReorder : stepsToReorder) stepToReorder.Name = EncodingUtil.base64encode(Crypto.generateAesKey(192));
            update stepsToReorder;
            
            //reposition them all
            Integer version = stepToDelete.Version__c.intValue();
            Integer position = 1;
            for (Step__c stepToReorder : stepsToReorder) {
                stepToReorder.Name = version + '#' + this.sequence.Name + '#' + position;
                stepToReorder.Position__c = position;
                position++;
            }
            
            update stepsToReorder;
        } catch (Exception e) {
            Database.rollback(savepoint);
            throw new ModelException('Could not destroy step "' + stepName + '"', e);
        }
    }
    
    /**
     * Per #1145 we need to afford ourselves this safety.
     * The async method decouples OUR steps from THEIR configs.
     * String avoids call-time exception for any kind of bad id.
     */
    @Future static void destroyStepConfig(String stepConfigId) {
        try {
            //all-or-none false per #1060
            Database.delete(stepConfigId, false);
        } catch (Exception e) {
            //show errors in dev orgs only
            if (Application__c.getOrgDefaults().Prefix__c == null) throw e;
        }
        
        try {
            //#1016 THEIR steps skip recycle bin
            Database.emptyRecycleBin(new List<Id>{stepConfigId});
        } catch (Exception e) {
            //show errors in dev orgs only
            if (Application__c.getOrgDefaults().Prefix__c == null) throw e;
        }
    }
    
    /**
     * #768 this is used to indicate there is work ongoing
     * by displaying a twirly alongside the count of messages
     * that are flowing through this sequence.
     */
    public Integer countRoutedMessages() {
        Integer total = 0;
        Integer version = SequenceSetModel.draftVersion();
        
        //#954 looped aggregate query to count > 50000 safely
        for (AggregateResult result : [
            SELECT COUNT(Id) total
            FROM Message__c
            WHERE Route__c LIKE :version + '#' + this.Sequence.Name + '#%'
            AND Status__c != 'Completed'
            AND Exception__c = null
            GROUP BY Route__c
        ]) total += (Integer)result.get('total');
        
        return total;
    }
    
    /**
     * This returns a list of Step DTOs with the minimum information seen by the user.
     * If a key is needed, we can use the Name, which serves as the unique routing key.
     * These DTOs would be consumed by the Sequence Builder interface, hiding our secret sauce.
     *
     * [
     *     {
     *         "Name": "Wiretaps#1",
     *         "ConfigId": null,
     *         "ConfigName": null,
     *         "ApexClassId": "01p000000000000AAA",
     *         "ApexTypeName": "Wiretap"
     *         "Position": 1.0,
     *     },
     *     {
     *         "Name": "Wiretaps#2",
     *         "ConfigId": null,
     *         "ConfigName": null,
     *         "ApexClassId": "01p000000000000AAA",
     *         "ApexTypeName": "Terminate"
     *         "Position": 2.0,
     *     }
     * ]
     */
    public List<Map<String,Object>> stepDtos() {
        
        //query fields
        List<Step__c> steps = [
            SELECT Id, Name, ConfigId__c, ConfigName__c, ApexClassId__c, ApexTypeName__c, Position__c
            FROM Step__c
            WHERE IsDraft__c = true
            AND Sequence__c = :this.sequence.Name
            ORDER BY Position__c ASC
        ];
        
        //prepare list of DTO
        List<Map<String,Object>> dtos = new List<Map<String,Object>>();
        
        for (Step__c step : steps) {
            Map<String,Object> dto = new Map<String,Object>{
                'Id' => step.Id,
                'Name' => step.Name,
                'ConfigId' => step.ConfigId__c,
                'ConfigName' => step.ConfigName__c,
                'ApexClassId' => step.ApexClassId__c,
                'ApexTypeName' => step.ApexTypeName__c,
                'Position' => step.Position__c.intValue()
            };
            
            dtos.add(dto);
        }
        
        return dtos;
    }
    
}