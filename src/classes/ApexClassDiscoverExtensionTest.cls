@IsTest class ApexClassDiscoverExtensionTest {
    
    static testmethod void coverCode() {
        //act
        new ApexClassDiscoverExtension(null);
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
    static testmethod void testDiscoverSummaries() {
        //arrange
        String namespace = 'test';
        
        //act
        List<ApexClassModel.Summary> summaries = ApexClassDiscoverExtension.DiscoverSummaries(namespace);
        
        //assert
        System.assert(summaries.isEmpty(), 'Wrong discovery.');
    }
    
    static testmethod void testGetNamespaces() {
        //arrange
        String namespaces;
        
        //act
        namespaces = ApexClassDiscoverExtension.getNamespaces();
        
        //assert
        System.assert(namespaces.contains('null'), 'Wrong namespace.');
    }
    
    static testmethod void testSaveCache() {
        //arrange
        String cache = '[]';
        
        //act
        String documentId = ApexClassDiscoverExtension.SaveCache(cache);
        
        //assert
        System.assert(documentId.startsWith('015'), 'Wrong id.');
    }
    
    
    
}