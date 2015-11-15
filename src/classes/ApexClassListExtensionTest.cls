@IsTest class ApexClassListExtensionTest {
    
    static testmethod void testDoRedirect() {
        //act
        PageReference redirect = new ApexClassListExtension().doRedirect();
        
        //assert
        System.assertNotEquals(null, redirect, 'Wrong redirect.');
        
        //arrange
        ApexClassSetModel.saveCache(ApexClassSetModel.fromNamespace('').discoverSummaries());
        
        //act
        redirect = new ApexClassListExtension().doRedirect();
        
        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
    }
    
}