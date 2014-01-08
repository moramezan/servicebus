Ext.define('Steps.model.override.ChainStep', {
    override: 'Steps.model.ChainStep'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.ChainStep__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.ChainStep__c.Fields.Name.Name;
    fields.Sequence.mapping = $ObjectType.ChainStep__c.Fields.Sequence__c.Name;
    fields.ProcessName.mapping = $ObjectType.ChainStep__c.Fields.Process__c.RelationshipName + '.' + $ObjectType.Process__c.Fields.Name.Name;
    fields.ProcessDescription.mapping = $ObjectType.ChainStep__c.Fields.Process__c.RelationshipName + '.'+$ObjectType.Process__c.Fields.Description__c.Name;
});