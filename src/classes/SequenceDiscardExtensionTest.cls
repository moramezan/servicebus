@IsTest class SequenceDiscardExtensionTest {

    static testmethod void coverDoCommit() {
        //assert
        System.assertEquals(null, new SequenceDiscardExtension(null).doDiscard(), 'Wrong redirect.');
        
        //arrange
        Test.setCurrentPage(new PageReference('/?id=707000000000000AAA'));
        SequenceDiscardExtension extension = new SequenceDiscardExtension(null);
        
        //act
        PageReference redirect = extension.doDiscard();
        
        //assert
        System.assert(redirect == null, 'Wrong redirect.');
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}