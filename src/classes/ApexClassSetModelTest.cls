@IsTest class ApexClassSetModelTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void testClassKey() {
        //act
        String classKey = ApexClassSetModel.classKey();
        
        //arrange
        List<ApexClass> apexClasses = [SELECT Id FROM ApexClass];
        
        //assert
        String expectedClassKey = '_' + apexClasses.size();
        String actualClassKey = '_' + classKey.substringAfterLast('_');
        System.assertEquals(expectedClassKey, actualClassKey, 'Wrong class key.');
    }
    
    static testmethod void testCacheKey() {
        //arrange
        insert new Document(
            Name = 'ApexClassCache.bin',
            Description = 'ApexClassCache_1447306203000_93',
            FolderId = [SELECT Id FROM Folder WHERE DeveloperName = 'Services'].Id
        );
        
        //act
        String cacheKey = ApexClassSetModel.cacheKey();
        
        //assert
        String expectedCacheKey = 'ApexClassCache_1447306203000_93';
        String actualCacheKey = cacheKey;
        System.assertEquals(expectedCacheKey, actualCacheKey, 'Wrong cache key.');
    }
    
    static testmethod void testSaveCache() {
        //arrange
        ApexClassModel.Definition definition = new ApexClassModel.Definition(TerminateService.class);
        
        //act
        Id documentId = ApexClassSetModel.saveCache(new Map<String,ApexClassModel.Definition>{
            TerminateService.class.getName() => definition
        });
        
        //arrange
        Document document = [SELECT Body FROM Document WHERE Id = :documentId];
        
        //assert
        String expectedBody = '"Label" : "Terminate"';
        String actualBody = document.Body.toString();
        System.assert(actualBody.contains(expectedBody), 'Wrong contains.');
    }
    
    static testmethod void testLoadCache() {
        //arrange
        Document document = new Document(
            Name = 'ApexClassCache.bin',
            FolderId = UserInfo.getUserId(),
            Body = Blob.valueOf('{"Test":{"Description":"Example"}}')
        );
        
        upsert document Schema.Document.Name;
        
        //act
        Map<String,ApexClassModel.Definition> name2definition = ApexClassSetModel.loadCache();
        
        //assert
        String expectedDescription = 'Example';
        String actualDescription = name2definition.get('Test').Description;
        System.assertEquals(expectedDescription, actualDescription, 'Wrong description.');
    }
    
    static testmethod void testFromNamespace() {
        //arrange
        String namespace = 'test';
        
        //act
        ApexClassSetModel model = ApexClassSetModel.fromNamespace(namespace);
        
        //assert
        System.assert(model.ApexClasses.isEmpty());
    }
    
    static testmethod void testDiscoverDefinitions() {
        //arrange
        ApexClassSetModel model = new ApexClassSetModel([
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Name = 'TerminateService'
            AND NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c
        ]);
        
        //act
        Map<String,ApexClassModel.Definition> name2definition = model.discoverDefinitions();
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = name2definition.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    static testmethod void testDiscoverNamespaces() {
        //act
        Set<String> namespaces = ApexClassSetModel.discoverNamespaces();
        
        //assert
        System.assert(namespaces.contains(Application__c.getOrgDefaults().Prefix__c));
    }
    
}