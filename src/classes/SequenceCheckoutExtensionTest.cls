@IsTest class SequenceCheckoutExtensionTest {

    static testmethod void coverDoCheckout() {
        //assert
        System.assertEquals(null, new SequenceCheckoutExtension(null).doCheckout(), 'Wrong redirect.');
        
        //arrange
        Test.setCurrentPage(new PageReference('/?id=707000000000000AAA'));
        SequenceCheckoutExtension extension = new SequenceCheckoutExtension(null);
        
        //act
        PageReference redirect = extension.doCheckout();
        
        //assert
        System.assert(redirect == null, 'Wrong redirect.');
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}