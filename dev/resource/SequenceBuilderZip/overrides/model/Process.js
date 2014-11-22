Ext.define('Override.model.Process', {
    override: 'Builder.model.Process'
}, function() {
    fields = Ext.Array.toValueMap(this.getFields(), 'name');
    fields.Id.mapping = $ObjectType.Process__c.Fields.Id.Name;
    fields.Name.mapping = $ObjectType.Process__c.Fields.Name.Name;
    fields.Tag.mapping = $ObjectType.Process__c.Fields.Tag__c.Name;
    fields.Icon.mapping = $ObjectType.Process__c.Fields.Icon__c.Name;
    fields.Description.mapping = $ObjectType.Process__c.Fields.Description__c.Name;
    fields.HelpUrl.mapping = $ObjectType.Process__c.Fields.HelpUrl__c.Name;
    fields.Setting.mapping = $ObjectType.Process__c.Fields.Setting__c.Name;
});