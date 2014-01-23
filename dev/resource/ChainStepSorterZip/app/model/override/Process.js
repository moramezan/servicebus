Ext.define('Steps.model.override.Process', {
    override: 'Steps.model.Process'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.Process__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.Process__c.Fields.Name.Name;
    fields.Tag.mapping = $ObjectType.Process__c.Fields.Tag__c.Name;
    fields.Icon.mapping = $ObjectType.Process__c.Fields.Icon__c.Name;
});