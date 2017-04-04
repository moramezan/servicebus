@IsTest class SequenceNewExtensionTest {
    
    static testmethod void coverCode() {
        //arrange
        SequenceNewExtension extension = new SequenceNewExtension(null);
        
        //act
        extension.doValidate();
        Integer draftVersion = extension.getDraftVersion();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}