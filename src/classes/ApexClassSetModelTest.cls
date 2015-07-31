@IsTest public class ApexClassSetModelTest {
    
    static testmethod void testDiscoverProcesses() {
        //arrange classes
        ApexClassSetModel.MockClasses = [
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Name IN ('ApexClassSetModelTest', 'Terminate', 'Wiretap') //ABC... TUV... WXY...
            ORDER BY Name ASC
            LIMIT 10000
        ];
        
        //act
        ApexClassSetModel model = ApexClassSetModel.discoverProcesses();
        
        //arrange
        List<ApexClass> apexClasses = model.getRecords();
        
        //assert
        Integer expectedSize = 2;
        Integer actualSize = apexClasses.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedName = 'Terminate';
        String actualName = apexClasses[0].Name;
        System.assertEquals(expectedName, actualName);
        
        expectedName = 'Wiretap';
        actualName = apexClasses[1].Name;
        System.assertEquals(expectedName, actualName);
    }
    
    static testmethod void testToDtos() {
        //arrange classes
        ApexClassSetModel.MockClasses = [
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Name IN ('Wiretap')
            ORDER BY Name ASC
            LIMIT 10000
        ];
        
        //act
        ApexClassSetModel model = ApexClassSetModel.discoverProcesses();
        
        //arrange
        List<Map<String,Object>> dtos = model.toDtos();
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = dtos.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //assert
        String expectedId = ApexClassSetModel.MockClasses[0].Id;
        String actualId = (String)dtos[0].get('Id');
        System.assertEquals(expectedId, actualId, 'Wrong Id.');
        
        String expectedName = new Wiretap.ESB().Name;
        String actualName = (String)dtos[0].get('Name');
        System.assertEquals(expectedName, actualName, 'Wrong Name.');
        
        String expectedDescription = new Wiretap.ESB().Description;
        String actualDescription = (String)dtos[0].get('Description');
        System.assertEquals(expectedDescription, actualDescription, 'Wrong Description.');
        
        String expectedTag = new Wiretap.ESB().Tag;
        String actualTag = (String)dtos[0].get('Tag');
        System.assertEquals(expectedTag, actualTag, 'Wrong Tag.');
        
        String expectedIcon = new Wiretap.ESB().Icon;
        String actualIcon = (String)dtos[0].get('Icon');
        System.assertEquals(expectedIcon, actualIcon, 'Wrong Icon.');
        
        String expectedCardinality = new Wiretap.ESB().Cardinality;
        String actualCardinality = (String)dtos[0].get('Cardinality');
        System.assertEquals(expectedCardinality, actualCardinality, 'Wrong Cardinality.');
        
        String expectedProcessSetting = new Wiretap.ESB().ProcessSetting;
        String actualProcessSetting = (String)dtos[0].get('ProcessSetting');
        System.assertEquals(expectedProcessSetting, actualProcessSetting, 'Wrong ProcessSetting.');
    }
    
}