Ext.define('Builder.model.override.Step', {
    override: 'Builder.model.Step'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.Step__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.Step__c.Fields.Name.Name;
    fields.Position.mapping = $ObjectType.Step__c.Fields.Position__c.Name;
    fields.ConfigId.mapping = $ObjectType.Step__c.Fields.ConfigId__c.Name;
    fields.ConfigName.mapping = $ObjectType.Step__c.Fields.ConfigName__c.Name;
    fields.ProcessId.mapping = $ObjectType.Step__c.Fields.Process__c.Name;
    fields.ProcessName.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Name.Name;
    fields.ProcessDescription.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Description__c.Name;
    fields.ProcessIcon.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Icon__c.Name;
    fields.ProcessHelpUrl.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.HelpUrl__c.Name;
    fields.ProcessSetting.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Setting__c.Name;
    fields.ProcessCardinality.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Cardinality__c.Name;
});