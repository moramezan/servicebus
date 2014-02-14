@isTest
private class LogConfigurationControllerTest{
    private static testMethod void controllerCoverage ()  { 
        // arrange
        LogConfiguration__c  logConfiguration = new LogConfiguration__c();
        insert logConfiguration;
        ApexPages.StandardController controller = new ApexPages.StandardController(logConfiguration);
        LogConfigurationController logConfigurationController =  new LogConfigurationController(controller);
        
        // act 
        System.PageReference pageRef = logConfigurationController.LogGroupView();    
    }
    
    
    private static testMethod void callingGetLogGroupPageReferenceReturnsExpectedPageReference ()  { 
    
        // arrange
        LogConfiguration__c  logConfiguration = new LogConfiguration__c();
        insert logConfiguration;
        Id logConfigurationId = logConfiguration.Id;
        String logGroupKeyPrefix  = LogGroup__c.SObjectType.getDescribe().getKeyPrefix();  
        String fakeLookUpFieldId = '000000000000000';
          
        // act
        System.PageReference pageRef  = LogConfigurationController.getLogGroupPageReference(logConfigurationId);
        
        
        // assemble
        String actualUrl = pageRef.getUrl();

                                    
        // assert
        String expectedUrl1 =  '/' + logGroupKeyPrefix ;
        String expectedUrl2 =  'rlid=' + fakeLookUpFieldId;
        String expectedUrl3 =  'id=' + logConfigurationId;
        System.assert(actualUrl.contains(expectedUrl1) );
        System.assert(actualUrl.contains(expectedUrl2) );
        System.assert(actualUrl.contains(expectedUrl3) );
    }
}