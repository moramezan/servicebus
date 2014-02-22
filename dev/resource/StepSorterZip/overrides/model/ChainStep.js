Ext.define('Override.model.Step', {
    override: 'Steps.model.Step'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.Step__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.Step__c.Fields.Name.Name;
    fields.Sequence.mapping = $ObjectType.Step__c.Fields.Sequence__c.Name;
    fields.ConfigurationId.mapping = $ObjectType.Step__c.Fields.ConfigurationId__c.Name;
    fields.ConfigurationName.mapping = $ObjectType.Step__c.Fields.ConfigurationName__c.Name;
    fields.ProcessName.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Name.Name;
    fields.ProcessDescription.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.'+$ObjectType.Process__c.Fields.Description__c.Name;
    fields.ProcessIcon.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.'+$ObjectType.Process__c.Fields.Icon__c.Name;
});