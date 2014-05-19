Ext.define('Override.model.Step', {
    override: 'Builder.model.Step'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.Step__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.Step__c.Fields.Name.Name;
    fields.Position.mapping = $ObjectType.Step__c.Fields.Position__c.Name;
    fields.ConfigurationId.mapping = $ObjectType.Step__c.Fields.ConfigurationId__c.Name;
    fields.ConfigurationName.mapping = $ObjectType.Step__c.Fields.ConfigurationName__c.Name;
    fields.ProcessId.mapping = $ObjectType.Step__c.Fields.Process__c.Name;
    fields.ProcessName.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Name.Name;
    fields.ProcessDescription.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Description__c.Name;
    fields.ProcessIcon.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Icon__c.Name;
    fields.ProcessDocsPageUrl.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.DocsPageUrl__c.Name;
    fields.ProcessCustomSetting.mapping = $ObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.CustomSetting__c.Name;
});