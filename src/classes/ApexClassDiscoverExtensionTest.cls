@IsTest class ApexClassDiscoverExtensionTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void coverCode() {
        //act
        new ApexClassDiscoverExtension(null);
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
    static testmethod void testDiscoverDefinitions() {
        //arrange
        String namespace = 'test';
        
        //act
        Map<String,ApexClassModel.Definition> name2definition = ApexClassDiscoverExtension.DiscoverDefinitions(namespace);
        
        //assert
        System.assert(name2definition.isEmpty(), 'Wrong discovery.');
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
        String cache = '{}';
        
        //act
        String documentId = ApexClassDiscoverExtension.SaveCache(cache);
        
        //assert
        System.assert(documentId.startsWith('015'), 'Wrong id.');
    }
    
    static testmethod void testDiscoverIfNeeded() {
        //arrange
        PageReference retURL = new PageReference('/home/home.jsp');
        
        //undiscover
        delete [SELECT Id FROM Document WHERE Name = 'ApexClassCache.bin'];
        
        //act
        PageReference redirect = ApexClassDiscoverExtension.DiscoverIfNeeded(retURL);
        
        //assert
        String expectedUrl = Page.ApexClassDiscover.getUrl();
        String actualUrl = redirect.getUrl();
        System.assert(actualUrl.containsIgnoreCase(expectedUrl), 'Wrong url.');
        System.assert(actualUrl.containsIgnoreCase('home.jsp'), 'Wrong retURL.');
        
        //act (pretend to discover)
        ApexClassSetModel.saveCache(ApexClassSetModel.fromNamespace(Application__c.getOrgDefaults().Prefix__c).discoverDefinitions());
        
        //act
        redirect = ApexClassDiscoverExtension.DiscoverIfNeeded(retURL);
        
        //assert
        System.assertEquals(null, redirect, 'Wrong url.');
    }
    
}