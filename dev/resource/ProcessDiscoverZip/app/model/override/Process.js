Ext.define('Discover.model.override.Process', {
    override: 'Discover.model.Process'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.Process__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.Process__c.Fields.Name.Name;
    fields.Description.mapping = $ObjectType.Process__c.Fields.Description__c.Name;
    fields.Tag.mapping = $ObjectType.Process__c.Fields.Tag__c.Name;
    fields.Icon.mapping = $ObjectType.Process__c.Fields.Icon__c.Name;
    fields.FullyQualifiedClassName.mapping = $ObjectType.Process__c.Fields.FullyQualifiedClassName__c.Name;
});