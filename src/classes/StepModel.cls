public with sharing class StepModel extends ApexDomain.StandardModel {

    private Step__c step;
    
    /**
     * For advertising domain layer errors
     */
    public without sharing class StepException extends Exception {}
    
    /**
     * Privatize constructor to force use of fromName() or fromId()
     */
    private StepModel(Step__c step) {
        super(step);
        this.step = step;
    }
    
    /**
     * Given a "step name" or "route", attempts to locate
     * the step custom setting instance with all fields.
     *
     * @throws StepException
     * @param step name or route
     * @return domain model of step
     */
    static public StepModel fromName(String stepName) {
        Step__c step = Step__c.getValues(stepName);
        if (step == null) throw new StepException('Could not locate step from name "' + stepName + '"');
        return new StepModel(step);
    }
    
    static public StepModel fromId(Id stepId) {
        Step__c step = (Step__c)ApexDomain.getById(stepId);
        return new StepModel(step);
    }
    
    /**
     * Moves a step within a sequence
     * and re-orders the other steps.
     */
    public void moveBefore(String beforeStepName) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
            
            Step__c stepToMove = this.step;
            Step__c beforeStep = Step__c.getValues(beforeStepName);
            
            //find all steps EXCEPT the guy we are moving
            List<Step__c> readSteps = [
                SELECT Name
                FROM Step__c
                WHERE SequenceName__c = :stepToMove.SequenceName__c
                AND Name != :stepToMove.Name
                ORDER BY Position__c ASC
            ];
            
            //normal case: inject the guy we are moving amongst the others
            List<Step__c> writeSteps = new List<Step__c>();
            for (Step__c step : readSteps) {
                if (step.Name == beforeStep.Name) writeSteps.add(stepToMove);
                writeSteps.add(step);
            }
            
            //custom settings not smart enough to recognize uniqueness in bulk update
            //https://developer.salesforce.com/forums/ForumsMain?id=906F00000008zF5IAI
            //so we have to make them unique first so that we can overwrite them second
            for (Step__c step : writeSteps) step.Name = EncodingUtil.base64encode(Crypto.generateAesKey(192));
            update writeSteps;
            
            //reposition them all
            Integer position = 1;
            for (Step__c step : writeSteps) {
                step.Name = this.step.SequenceName__c + '#' + position;
                step.Position__c = position;
                position++;
            }
            
            update writeSteps;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new StepException('Could not move step "' + this.step.Name + '" before "' + beforeStepName + '"', e);
        }
    }
    
    /**
     * Moves a step within a sequence
     * and re-orders the other steps.
     */
    public void moveAfter(String afterStepName) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
            
            Step__c stepToMove = this.step;
            Step__c afterStep = Step__c.getValues(afterStepName);
            
            //find all steps EXCEPT the guy we are moving
            List<Step__c> readSteps = [
                SELECT Name
                FROM Step__c
                WHERE SequenceName__c = :stepToMove.SequenceName__c
                AND Name != :stepToMove.Name
                ORDER BY Position__c ASC
            ];
            
            //normal case: inject the guy we are moving amongst the others
            List<Step__c> writeSteps = new List<Step__c>();
            for (Step__c step : readSteps) {
                writeSteps.add(step);
                if (step.Name == afterStep.Name) writeSteps.add(stepToMove);
            }
            
            //custom settings not smart enough to recognize uniqueness in bulk update
            //https://developer.salesforce.com/forums/ForumsMain?id=906F00000008zF5IAI
            //so we have to make them unique first so that we can overwrite them second
            for (Step__c step : writeSteps) step.Name = EncodingUtil.base64encode(Crypto.generateAesKey(192));
            update writeSteps;
            
            //reposition them all
            Integer position = 1;
            for (Step__c step : writeSteps) {
                step.Name = this.step.SequenceName__c + '#' + position;
                step.Position__c = position;
                position++;
            }
            
            update writeSteps;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new StepException('Could not move step "' + this.step.Name + '" after "' + afterStepName + '"', e);
        }
    }
    
    public void upsertConfig() {
        //use apex class name instead of id, for easier testing
        Type reflector = Type.forName(this.Step.ApexClassName__c);
        ApexClassModel model = new ApexClassModel(reflector);
        
        if (model.esb.StepConfig == null) {
            //process has no config
            return;
        }
        
        if (ApexDomain.exists(this.Step.ConfigId__c)) {
            //config already exists
            return;
        }
        
        //get type without using global describe
        SObject prototype = (SObject)Type.forName(model.esb.StepConfig).newInstance();
        SObjectType objectType = prototype.getSObjectType();
        
        //new up with defaults
        Id recordTypeId = null;
        Boolean loadDefaults = true;
        SObject config = objectType.newSObject(recordTypeId, loadDefaults);
        insert config;
        
        //get the name
        Id configId = config.Id;
        config = Database.query('SELECT Id, Name FROM ' + model.esb.StepConfig + ' WHERE Id = :configId');
        
        this.Step.ConfigId__c = (Id)config.get('Id');
        this.Step.ConfigName__c = (String)config.get('Name');
        update this.Step;
    }
    
    public PageReference showConfig() {
        Id configId = this.Step.ConfigId__c;
        SObject config = configId.getSObjectType().newSObject(configId);
        return new ApexPages.StandardController(config).view();
    }
    
    /**
     * Locates a Step and his related StepConfig
     * and caches the friendly name on the step.
     *
     * @param configId of any StepConfig
     */
    public void cacheConfigName() {
        Id configId = this.Step.ConfigId__c;
        Step__c step = [SELECT Name FROM Step__c WHERE ConfigId__c = :configId];
        String objectType = configId.getSObjectType().getDescribe().getName();
        SObject config = Database.query('SELECT Id, Name FROM ' + objectType + ' WHERE Id = :configId');
        String configName = (String)config.get('Name');
        step.ConfigName__c = configName.abbreviate(SObjectType.Step__c.Fields.ConfigName__c.Length);
        update step;
    }
    
}