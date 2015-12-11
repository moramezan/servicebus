@IsTest(SeeAllData=true) class PostUninstallHandlerTest {
    
    static testmethod void testCacheIsNotPackaged() {
        //arrange
        Folder folder = [SELECT Id FROM Folder WHERE DeveloperName = 'ServiceBus'];
        
        //act
        List<Document> documents = [SELECT Id FROM Document WHERE FolderId = :folder.Id];
        
        //assert
        Integer expectedSize = 1; //for the image
        Integer actualSize = documents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong documents size.');
    }
    
}