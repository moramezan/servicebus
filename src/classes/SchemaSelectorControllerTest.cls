@isTest public class SchemaSelectorControllerTest {
    
    static testMethod void testDoSave() {
        //arrange config
        IsChangedConfiguration__c config = new IsChangedConfiguration__c();
        insert config;
        
        //arrange page context
        PageReference pr = Page.SchemaSelector;
        pr.getParameters().put('id', config.Id);
        pr.getParameters().put('objectSchemaKey', SObjectType.IsChangedConfiguration__c.Fields.ObjectName__c.Name);
        pr.getParameters().put('fieldSchemaKey', SObjectType.IsChangedConfiguration__c.Fields.FieldName__c.Name);
        pr.getParameters().put('retURL', '/home/home.jsp');
        Test.setCurrentPageReference(pr);
        
        //arrange controller context
        SchemaSelectorController controller = new SchemaSelectorController();
        controller.ObjectName = 'Account';
        controller.FieldName = 'Name';
        
        //act
        PageReference redirect = controller.doSave();

        //assemble
        config = [SELECT Id, ObjectName__c, FieldName__c FROM IsChangedConfiguration__c];
        
        //assert
        String expectedUrl = '/home/home.jsp';
        String actualUrl = redirect.getUrl();
        System.assertEquals(expectedUrl, actualUrl);
        
        String expectedObjectName = 'Account';
        String actualObjectName = config.ObjectName__c;
        System.assertEquals(expectedObjectName, ActualObjectName);
        
        String expectedFieldName = 'Name';
        String actualFieldName = config.FieldName__c;
        System.assertEquals(expectedFieldName, actualFieldName);
    }
    
    static testMethod void testDoCancel() {
        //arrange config
        IsChangedConfiguration__c config = new IsChangedConfiguration__c();
        insert config;
        
        //arrange page context
        PageReference pr = Page.SchemaSelector;
        pr.getParameters().put('id', config.Id);
        Test.setCurrentPageReference(pr);
        
        //arrange controller context
        SchemaSelectorController controller = new SchemaSelectorController();
        
        //act
        PageReference redirect = controller.doCancel();
        
        //assert
        String expectedUrl = String.valueOf(config.Id).left(15);
        String actualUrl = redirect.getUrl();
        System.assert(actualUrl.contains(expectedUrl));
    }
    
    static testMethod void testGetDescribe() {
        //arrange config
        IsChangedConfiguration__c config = new IsChangedConfiguration__c();
        insert config;
        
        //arrange page context
        PageReference pr = Page.SchemaSelector;
        pr.getParameters().put('id', config.Id);
        Test.setCurrentPageReference(pr);
        
        //arrange controller
        SchemaSelectorController controller = new SchemaSelectorController();
        
        //act
        DescribeSObjectResult description = controller.getDescribe();
        
        //assert
        String expectedName = 'IsChanged Configuration';
        String actualName = description.getLabel();
        System.assertEquals(expectedName, actualName);
    }
    
    static testMethod void testPopulateObjectNameOptions() {
        //arrange controller
        SchemaSelectorController controller = new SchemaSelectorController();
        
        //act
        controller.populateObjectNameOptions();
        
        //assemble 
        List<SelectOption> options = controller.ObjectNameOptions;
        
        //assert
        Boolean found = false;
        for (SelectOption option : options) if (option.getValue() == 'Account') found = true;
        System.assert(found);
    }
    
    static testMethod void testPopulateFieldNameOptions() {
        //arrange controller
        SchemaSelectorController controller = new SchemaSelectorController();
        controller.ObjectName = 'Account';
        
        //act
        controller.populateFieldNameOptions();
        
        //assemble
        List<SelectOption> options = controller.FieldNameOptions;
        
        //assert
        Boolean found = false;
        for (SelectOption option : options) if (option.getValue() == 'Name') found = true;
        System.assert(found);
    }
    
}