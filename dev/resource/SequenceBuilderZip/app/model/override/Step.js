Ext.define('Builder.model.override.Step', {
    override: 'Builder.model.Step'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.Step__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.Step__c.Fields.Name.Name;
    fields.Position.mapping = $ObjectType.Step__c.Fields.Position__c.Name;
    fields.ConfigId.mapping = $ObjectType.Step__c.Fields.ConfigId__c.Name;
    fields.ConfigName.mapping = $ObjectType.Step__c.Fields.ConfigName__c.Name;
    fields.FullyQualifiedClassName.mapping = $ObjectType.Step__c.Fields.FullyQualifiedClassName__c.Name;
});