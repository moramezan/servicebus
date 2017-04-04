@IsTest class SequenceCommitExtensionTest {

    static testmethod void coverDoCommit() {
        //assert
        System.assertEquals(null, new SequenceCommitExtension(null).doCommit(), 'Wrong redirect.');
        
        //arrange
        Test.setCurrentPage(new PageReference('/?id=707000000000000AAA'));
        SequenceCommitExtension extension = new SequenceCommitExtension(null);
        
        //act
        PageReference redirect = extension.doCommit();
        
        //assert
        System.assert(redirect == null, 'Wrong redirect.');
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}