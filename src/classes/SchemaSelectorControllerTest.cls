@IsTest public class SchemaSelectorControllerTest {
    
    static testmethod void testSelectionFromLogConfiguration() {
        //arrange log configuration
        LogConfiguration__c config = new LogConfiguration__c();
        insert config;
        
        //arrange page
        PageReference pr = Page.SchemaSelector;
        Test.setCurrentPage(pr);
        pr.getParameters().putAll(new Map<String,String>{
            'id' => config.Id,
            'objectSchemaKey' => SObjectType.LogConfiguration__c.Fields.DynamicGroupIdentifierObjectName__c.Name,
            'fieldSchemaKey' => SObjectType.LogConfiguration__c.Fields.DynamicGroupIdentifier__c.Name,
            'retURL' => new ApexPages.StandardController(config).view().getUrl()
        });
        
        //arrange controller
        SchemaSelectorController controller = new SchemaSelectorController();
        
        //act on initial display
        controller.doInit();
        
        //assert number of available objects
        Integer expectedObjects = Schema.getGlobalDescribe().size();
        Integer actualObjects = controller.ObjectNameOptions.size();
        System.assertEquals(expectedObjects, actualObjects);
        
        //act on object selection
        controller.ObjectName = SObjectType.Account.Name;
        controller.populateFieldNameOptions();
        
        //assert number of available fields
        Integer expectedFields = SObjectType.Account.Fields.getMap().size();
        Integer actualFields = controller.FieldNameOptions.size();
        System.assertEquals(expectedFields, actualFields);
        
        //act on field selection and save
        controller.FieldName = SObjectType.Account.Fields.Industry.Name;
        controller.populateFieldNameOptions();
        PageReference redirect = controller.doSave();
        
        //assemble
        config = [
            SELECT Id, DynamicGroupIdentifierObjectName__c, DynamicGroupIdentifier__c
            FROM LogConfiguration__c
            WHERE Id = :config.Id
        ];
        
        //assert
        String expectedObjectName = SObjectType.Account.Name;
        String actualObjectName = config.DynamicGroupIdentifierObjectName__c;
        System.assertEquals(expectedObjectName, actualObjectName);
        
        String expectedFieldName = SObjectType.Account.Fields.Industry.Name;
        String actualFieldName = config.DynamicGroupIdentifier__c;
        System.assertEquals(expectedFieldName, actualFieldName);
        
        String expectedUrl = String.valueOf(config.Id).left(15);
        String actualUrl = redirect.getUrl();
        System.assert(actualUrl.contains(expectedUrl));
    }

}