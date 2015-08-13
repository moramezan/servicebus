@IsTest public class ApexClassSetModelTest {
    
    static testmethod void testDiscoverProcesses() {
        //act
        Id apexClassId = [SELECT Id FROM ApexClass WHERE Name = 'Terminate'].Id;
        ApexClassSetModel model = ApexClassSetModel.discoverProcesses(new Set<Id>{apexClassId});
        
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
        ApexClassSetModel model = ApexClassSetModel.discoverProcesses(new Set<Id>{apexClassId});
        
        //act
        List<Map<String,Object>> dtos = model.toDtos();
        
        //assemble
        ApexClassModel.Summary esb = ApexClassModel.esbFromEsb(Wiretap.class);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = dtos.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedId = apexClassId;
        String actualId = (String)dtos[0].get('Id');
        System.assertEquals(expectedId, actualId, 'Wrong Id.');
        
        String expectedName = esb.Name;
        String actualName = (String)dtos[0].get('Name');
        System.assertEquals(expectedName, actualName, 'Wrong Name.');
        
        String expectedDescription = esb.Description;
        String actualDescription = (String)dtos[0].get('Description');
        System.assertEquals(expectedDescription, actualDescription, 'Wrong Description.');
        
        String expectedTag = esb.Tag;
        String actualTag = (String)dtos[0].get('Tag');
        System.assertEquals(expectedTag, actualTag, 'Wrong Tag.');
        
        String expectedIcon = esb.Icon;
        String actualIcon = (String)dtos[0].get('Icon');
        System.assertEquals(expectedIcon, actualIcon, 'Wrong Icon.');
        
        String expectedCardinality = esb.Cardinality;
        String actualCardinality = (String)dtos[0].get('Cardinality');
        System.assertEquals(expectedCardinality, actualCardinality, 'Wrong Cardinality.');
        
        String expectedProcessSetting = esb.ProcessSetting;
        String actualProcessSetting = (String)dtos[0].get('ProcessSetting');
        System.assertEquals(expectedProcessSetting, actualProcessSetting, 'Wrong ProcessSetting.');
    }
    
}