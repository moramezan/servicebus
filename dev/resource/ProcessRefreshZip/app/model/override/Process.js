Ext.define('Refresh.model.override.Process', {
    override: 'Refresh.model.Process'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.Process__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.Process__c.Fields.Name.Name;
    fields.Description.mapping = $ObjectType.Process__c.Fields.Description__c.Name;
});