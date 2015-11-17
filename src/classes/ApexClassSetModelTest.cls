@IsTest class ApexClassSetModelTest {

    @TestSetup static void testSetup() {
        new PostInstallHandler().upsertNamespaceSetting();
    }
    
    static testmethod void testClassKey() {
        //act
        String classKey = ApexClassSetModel.classKey();
        
        //arrange
        List<ApexClass> apexClasses = [SELECT Id FROM ApexClass];
        
        //assert
        String expectedClassKey = '_' + apexClasses.size();
        String actualClassKey = '_' + classKey.substringAfter('_');
        System.assertEquals(expectedClassKey, actualClassKey, 'Wrong class key.');
    }
    
    static testmethod void testCacheKey() {
        //arrange
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
        setting.CacheKey__c = '1447306203000_93';
        upsert setting;
        
        //act
        String cacheKey = ApexClassSetModel.cacheKey();
        
        //assert
        String expectedCacheKey = '1447306203000_93';
        String actualCacheKey = cacheKey;
        System.assertEquals(expectedCacheKey, actualCacheKey, 'Wrong cache key.');
    }
    
    static testmethod void testSaveCache() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Terminate.class);
        
        //act
        Id documentId = ApexClassSetModel.saveCache(new List<ApexClassModel.Summary>{summary});
        
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
            Body = Blob.valueOf('[{"Description":"Test"}]')
        );
        
        upsert document Name;
        document.DeveloperName = 'ApexClassDiscover';
        update document; //cant upsert on DeveloperName
        
        //act
        List<ApexClassModel.Summary> summaries = ApexClassSetModel.loadCache();
        
        //assert
        String expectedDescription = 'Test';
        String actualDescription = summaries[0].Description;
        System.assertEquals(expectedDescription, actualDescription, 'Wrong id.');
    }
    
    static testmethod void testFromNamespace() {
        //arrange
        String namespace = 'test';
        
        //act
        ApexClassSetModel model = ApexClassSetModel.fromNamespace(namespace);
        
        //assert
        System.assert(model.ApexClasses.isEmpty());
    }
    
    static testmethod void testDiscoverSummaries() {
        //arrange
        ApexClassSetModel model = new ApexClassSetModel([
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Name = 'Terminate'
            AND NamespacePrefix = :NamespaceSetting__c.getOrgDefaults().Prefix__c
        ]);
        
        //act
        List<ApexClassModel.Summary> summaries = model.discoverSummaries();
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = summaries.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    static testmethod void testDiscoverNamespaces() {
        //act
        Set<String> namespaces = ApexClassSetModel.discoverNamespaces();
        
        //assert
        System.assert(namespaces.contains(NamespaceSetting__c.getOrgDefaults().Prefix__c));
    }
    
}