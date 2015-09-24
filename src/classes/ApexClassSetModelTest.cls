@IsTest public class ApexClassSetModelTest {
    
    static testmethod void testDiscoverServices() {
        //act
        Id apexClassId = [SELECT Id FROM ApexClass WHERE Name = 'Terminate'].Id;
        ApexClassSetModel model = ApexClassSetModel.discoverServices(new Set<Id>{apexClassId});
        
        //assemble
        List<ApexClass> apexClasses = model.getRecords();
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = apexClasses.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedName = 'Terminate';
        String actualName = apexClasses[0].Name;
        System.assertEquals(expectedName, actualName, 'Wrong name.');
    }
    
    static testmethod void testToDtos() {
        //arrange
        Id apexClassId = [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
        ApexClassSetModel model = ApexClassSetModel.discoverServices(new Set<Id>{apexClassId});
        
        //act
        List<Map<String,Object>> dtos = model.toDtos();
        
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Wiretap.class);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = dtos.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedId = apexClassId;
        String actualId = (String)dtos[0].get('Id');
        System.assertEquals(expectedId, actualId, 'Wrong Id.');
        
        String expectedName = summary.Label;
        String actualName = (String)dtos[0].get('Label');
        System.assertEquals(expectedName, actualName, 'Wrong Name.');
        
        String expectedDescription = summary.Description;
        String actualDescription = (String)dtos[0].get('Description');
        System.assertEquals(expectedDescription, actualDescription, 'Wrong Description.');
        
        String expectedTag = summary.Tag;
        String actualTag = (String)dtos[0].get('Tag');
        System.assertEquals(expectedTag, actualTag, 'Wrong Tag.');
        
        String expectedIcon = summary.Icon;
        String actualIcon = (String)dtos[0].get('Icon');
        System.assertEquals(expectedIcon, actualIcon, 'Wrong Icon.');
        
        String expectedCardinality = summary.Cardinality;
        String actualCardinality = (String)dtos[0].get('Cardinality');
        System.assertEquals(expectedCardinality, actualCardinality, 'Wrong Cardinality.');
        
        String expectedServiceSetting = summary.ServiceSetting;
        String actualServiceSetting = (String)dtos[0].get('ServiceSetting');
        System.assertEquals(expectedServiceSetting, actualServiceSetting, 'Wrong ServiceSetting.');
    }
    
}