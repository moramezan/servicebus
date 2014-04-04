@isTest
private class ProcessApexClassExtensionTest{
    private static testMethod void callingViewPageReturnsExpectedUrl ()  {
        // arrange
        Process__c process = ProcessSet.generateOne(Publish.class);
        ApexPages.StandardController controller = new ApexPages.StandardController(process);
        ProcessApexClassExtension ProcessApexClassExtension =  new ProcessApexClassExtension(controller);
        
        List<ApexClass> apexClasses = [SELECT Id FROM ApexClass WHERE Name = 'Publish'];
        Id actualApexClassId;
        if (apexClasses.size() > 0) {
        actualApexClassId = apexClasses[0].Id;
        }
        
        // act
        System.PageReference pageRef = ProcessApexClassExtension.ViewPage();
        
        
        //assert
        System.assert(actualApexClassId != null);
        System.assert(pageRef.getUrl().contains(actualApexClassId));
    }
    
    private static testMethod void callingViewPageThowsExpectedExceptionWhenNoFullyQualifiedClassDefined ()  {
        // arrange
        Process__c process = new Process__c();
        insert process;
        ApexPages.StandardController controller = new ApexPages.StandardController(process);
        ProcessApexClassExtension ProcessApexClassExtension =  new ProcessApexClassExtension(controller);
        
        String actualMessage;
        Boolean actualFlag = false;
        try {
            // act
            System.PageReference pageRef = ProcessApexClassExtension.ViewPage();
        } catch (Exception e) {
            actualMessage = e.getMessage();
            actualFlag = true;
        }
        
        //assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
        String  expectedMessage = 'Cannot determine fully qualified class name';
        System.assert(actualMessage.contains(expectedMessage));
    }   
    
    private static testMethod void callingViewPageThowsExpectedExceptionWhenFullyQualifiedClassNotValid ()  {
        // arrange
        Process__c process = new Process__c();
        process.FullyQualifiedClassName__c ='FakeApexClass';
        insert process;
        ApexPages.StandardController controller = new ApexPages.StandardController(process);
        ProcessApexClassExtension ProcessApexClassExtension =  new ProcessApexClassExtension(controller);
        
        String actualMessage;
        Boolean actualFlag = false;
        try {
            // act
            System.PageReference pageRef = ProcessApexClassExtension.ViewPage();
        } catch (Exception e) {
            actualMessage = e.getMessage();
            actualFlag = true;
        }
        
        //assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
        String  expectedMessage = 'Cannot derive apex class';
        System.assert(actualMessage.contains(expectedMessage));
    }     
}