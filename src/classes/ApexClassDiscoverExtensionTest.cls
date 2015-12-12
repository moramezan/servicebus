@IsTest class ApexClassDiscoverExtensionTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().upsertApplication();
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
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
        System.assert(namespaces.contains('' + Application__c.getOrgDefaults().Prefix__c + ''), 'Wrong namespace.');
    }
    
    static testmethod void testSaveCache() {
        //arrange
        String cache = '[]';
        
        //act
        String documentId = ApexClassDiscoverExtension.SaveCache(cache);
        
        //assert
        System.assert(documentId.startsWith('015'), 'Wrong id.');
    }
    
    static testmethod void testDiscoverIfNeeded() {
        //arrange
        PageReference retURL = new PageReference('/home/home.jsp');
        
        //act
        PageReference redirect = ApexClassDiscoverExtension.DiscoverIfNeeded(retURL);
        
        //assert
        String expectedUrl = Page.ApexClassDiscover.getUrl();
        String actualUrl = redirect.getUrl();
        System.assert(actualUrl.containsIgnoreCase(expectedUrl), 'Wrong url.');
        System.assert(actualUrl.containsIgnoreCase('home.jsp'), 'Wrong retURL.');
        
        //act (pretend to discover)
        ApexClassSetModel.saveCache(ApexClassSetModel.fromNamespace(Application__c.getOrgDefaults().Prefix__c).discoverSummaries());
        
        //act
        redirect = ApexClassDiscoverExtension.DiscoverIfNeeded(retURL);
        
        //assert
        System.assertEquals(null, redirect, 'Wrong url.');
    }
    
}