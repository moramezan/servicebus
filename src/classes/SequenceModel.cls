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
        Decimal version = (Decimal)[
            SELECT AVG(Version__c)
            FROM Step__c
            WHERE IsDraft__c = true
        ][0].get('expr0');
        
        if (version == null) version = 1;
        
        //initial position
        Decimal position = 0;
        
        Job.AllowRoute = true; //#999#issuecomment-133751700
        Map<String,Object> event = new Map<String,Object>{
            'Route' => version.intValue() + '#' + this.Sequence.Name + '#' + position.intValue()
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
            Decimal version = (Decimal)[
                SELECT AVG(Version__c)
                FROM Step__c
                WHERE IsDraft__c = true
            ][0].get('expr0');
            
            if (version == null) version = 1;
            
            //last sibling position
            Decimal position = (Decimal)[
                SELECT MAX(Position__c)
                FROM Step__c
                WHERE IsDraft__c = true
                AND Sequence__c = :this.sequence.Name
            ][0].get('expr0');
            
            //next position after siblings
            if (position == null) position = 1; else position++;
            
            Step__c step = new Step__c(
                IsDraft__c = true,
                Version__c = version.intValue(),
                Name = version.intValue() + '#' + this.sequence.Name + '#' + position.intValue(),
                Sequence__c = this.sequence.Name,
                ApexClassId__c = null, //see upstairs
                ApexClassName__c = reflector.getName(),
                Position__c = position.intValue()
            );
            
            insert step;
            return Step__c.getValues(step.Name);
        } catch (DmlException e) {
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
                AND ApexClassName__c = :Terminate.class.getName()
            ];
        } catch (QueryException e) {
            //sequence contains no terminate step
            ApexClass apexClass = [
                SELECT Id, NamespacePrefix, Name
                FROM ApexClass
                WHERE NamespacePrefix = :NamespaceSetting__c.getOrgDefaults().Prefix__c
                AND Name = 'Terminate'
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
        Savepoint sp = Database.setSavepoint();
        try {
            Step__c stepToDelete = Step__c.getValues(stepName);
            
            //perform the delete
            delete stepToDelete;
            Database.emptyRecycleBin(stepToDelete); //#1016
            
            //any config to delete, all-or-none false per #1060
            if (stepToDelete.ConfigId__c != null) Database.delete(stepToDelete.ConfigId__c, false);
            if (stepToDelete.ConfigId__c != null) Database.emptyRecycleBin(new List<Id>{stepToDelete.ConfigId__c}); //#1016
            
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
            Decimal position = 1;
            for (Step__c stepToReorder : stepsToReorder) {
                stepToReorder.Name = stepToDelete.Version__c.intValue() + '#' + this.sequence.Name + '#' + position.intValue();
                stepToReorder.Position__c = position.intValue();
                position++;
            }
            
            update stepsToReorder;
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new ModelException('Could not destroy step "' + stepName + '"', e);
        }
    }
    
    /**
     * #768 this is used to indicate there is work ongoing
     * by displaying a twirly alongside the count of messages
     * that are flowing through this sequence.
     */
    public Integer countRoutedMessages() {
        Integer total = 0;
        
        //#954 looped aggregate query to count > 50000 safely
        for (AggregateResult result : [
            SELECT COUNT(Id) total
            FROM Message__c
            WHERE Route__c LIKE :this.Sequence.Name + '#%'
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
     *         "ApexClassName": "Wiretap"
     *         "Position": 1.0,
     *     },
     *     {
     *         "Name": "Wiretaps#2",
     *         "ConfigId": null,
     *         "ConfigName": null,
     *         "ApexClassId": "01p000000000000AAA",
     *         "ApexClassName": "Terminate"
     *         "Position": 2.0,
     *     }
     * ]
     */
    public List<Map<String,Object>> stepDtos() {
        
        //query fields
        List<Step__c> steps = [
            SELECT Id, Name, ConfigId__c, ConfigName__c, ApexClassId__c, ApexClassName__c, Position__c
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
                'ApexClassName' => step.ApexClassName__c,
                'Position' => step.Position__c.intValue()
            };
            
            dtos.add(dto);
        }
        
        return dtos;
    }
    
}