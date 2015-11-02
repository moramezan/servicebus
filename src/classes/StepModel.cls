public class StepModel extends ApexDomain.StandardModel {

    private Step__c step;
    
    /**
     * For advertising domain layer errors
     */
    public class StepException extends Exception {}
    
    /**
     * Privatize constructor to force use of fromName() or fromId()
     */
    @TestVisible private StepModel(Step__c step) {
        super(step);
        this.step = step;
    }
    
    /**
     * Given a step name aka Route, attempts to locate
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
            
            //find all steps EXCEPT the guy we are moving
            List<Step__c> readSteps = [
                SELECT Name
                FROM Step__c
                WHERE IsDraft__c = true
                AND Version__c = :this.step.Version__c
                AND Sequence__c = :this.step.Sequence__c
                AND Name != :this.step.Name
                ORDER BY Position__c ASC
            ];
            
            //normal case: inject the guy we are moving amongst the others
            Step__c beforeStep = Step__c.getValues(beforeStepName);
            List<Step__c> writeSteps = new List<Step__c>();
            for (Step__c step : readSteps) {
                if (step.Name == beforeStep.Name) writeSteps.add(this.step);
                writeSteps.add(step);
            }
            
            //custom settings not smart enough to recognize uniqueness in bulk update
            //https://developer.salesforce.com/forums/ForumsMain?id=906F00000008zF5IAI
            //so we have to make them unique first so that we can overwrite them second
            for (Step__c step : writeSteps) step.Name = EncodingUtil.base64encode(Crypto.generateAesKey(192));
            update writeSteps;
            
            //reposition them all
            Decimal position = 1;
            for (Step__c step : writeSteps) {
                step.Name = this.step.Version__c.intValue() + '#' + this.step.Sequence__c + '#' + position.intValue();
                step.Position__c = position.intValue();
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
            
            //find all steps EXCEPT the guy we are moving
            List<Step__c> readSteps = [
                SELECT Name
                FROM Step__c
                WHERE IsDraft__c = true
                AND Version__c = :this.step.Version__c
                AND Sequence__c = :this.step.Sequence__c
                AND Name != :this.step.Name
                ORDER BY Position__c ASC
            ];
            
            //normal case: inject the guy we are moving amongst the others
            Step__c afterStep = Step__c.getValues(afterStepName);
            List<Step__c> writeSteps = new List<Step__c>();
            for (Step__c step : readSteps) {
                writeSteps.add(step);
                if (step.Name == afterStep.Name) writeSteps.add(this.step);
            }
            
            //custom settings not smart enough to recognize uniqueness in bulk update
            //https://developer.salesforce.com/forums/ForumsMain?id=906F00000008zF5IAI
            //so we have to make them unique first so that we can overwrite them second
            for (Step__c step : writeSteps) step.Name = EncodingUtil.base64encode(Crypto.generateAesKey(192));
            update writeSteps;
            
            //reposition them all
            Decimal position = 1;
            for (Step__c step : writeSteps) {
                step.Name = this.step.Version__c.intValue() + '#' + this.step.Sequence__c + '#' + position.intValue();
                step.Position__c = position.intValue();
                position++;
            }
            
            update writeSteps;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new StepException('Could not move step "' + this.step.Name + '" after "' + afterStepName + '"', e);
        }
    }
    
    public Id upsertConfig() {
        //use apex class name instead of id, for easier testing
        Type reflector = Type.forName(this.Step.ApexClassName__c);
        ApexClassModel.Summary summary = new ApexClassModel.Summary(reflector);
        
        if (summary.StepConfig == null) {
            //service has no config
            return null;
        }
        
        if (ApexDomain.exists(this.Step.ConfigId__c)) {
            //config already exists
            return this.Step.ConfigId__c;
        }
        
        //describe object and name field dynamically
        SObjectType objectType = Schema.getGlobalDescribe().get(summary.StepConfig);
        DescribeSObjectResult result = objectType.getDescribe();
        DescribeFieldResult field = result.Fields.getMap().get('Name').getDescribe();
        
        if (result.isCustomSetting() && field.getLength() == 80) {
            //HIERARCHY SETTING
            throw new StepException('Hierarchy Custom Settings are not supported for Step Config.');
        }
        
        SObject config = objectType.newSObject(null, true);
        
        if (result.isCustomSetting() && field.getLength() == 38) {
            //LIST SETTING
            config.put('Name', this.Step.Id); //unique
        }
        
        insert config; //with default field values
        config.put('Name', config.Id);
        update config;
        
        this.Step.ConfigId__c = config.Id;
        update this.Step;
        return config.Id;
    }
    
    /**
     * Used to determine the list/tab redirect
     * when showing the StepConfig page
     */
    public PageReference showConfig() {
        Id configId = this.Step.ConfigId__c;
        Sobject config = configId.getSobjectType().newSobject(configId);
        PageReference view = new ApexPages.StandardController(config).view();
        
        if (!configId.getSobjectType().getDescribe().isCustomSetting()) {
            //console style only for custom objects
            view.getParameters().put('isdtp', 'vw');
        }
        
        return view;
    }
    
    /**
     * Copies third-party step config name
     * so sequence builder can describe steps
     */
    public void persistConfigNameOnStep() {
        Id configId = this.Step.ConfigId__c;
        String objectType = configId.getSObjectType().getDescribe().getName();
        SObject config = Database.query('SELECT Id, Name FROM ' + objectType + ' WHERE Id = :configId');
        
        //write THEIR config name onto OUR step
        String configName = (String)config.get('Name');
        this.Step.ConfigName__c = configName.abbreviate(SObjectType.Step__c.Fields.ConfigName__c.Length);
        update this.Step;
    }
    
}