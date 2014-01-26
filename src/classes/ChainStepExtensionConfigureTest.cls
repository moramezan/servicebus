@isTest  //-- no view of org data
private  class ChainStepExtensionConfigureTest {
    static testMethod void callingInitConfigWhenConfigurationIdNotNullReturnsExpectedUrl() {
        //arrange processes
        Process__c branchProcess = Processes.generateOne(Branch.class);
        
        //arrange chain
        Chain__c chain = new Chain__c( Name = 'the-chain');
        insert chain;
        
        //arrange steps
        ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, branchProcess.Id);

        String expectedPageReferenceUrl = new PageReference('/' + chainStep.ConfigurationId__c + '/e?retURL=' + chainStep.Id).getUrl();

        // Act
        ApexPages.StandardController controller = new ApexPages.StandardController(chainStep);
        ChainStepExtensionConfigure chainStepExtensionConfigure = new ChainStepExtensionConfigure( controller );
        String actualPageReferenceUrl = chainStepExtensionConfigure.initConfig().getUrl();

        // Assert
        System.assertEquals(expectedPageReferenceUrl , actualPageReferenceUrl );
        /////// expectedPageReferenceUrl=[ /null/e?retURL=a02b0000008Ewn5AAC ], actualPageReferenceUrl=[ /a02b0000008Ewn5 ]
    }

    static testMethod void callingInitConfigWhenConfigurationIdIsNullReturnsExpectedUrl() {
        //arrange processes
        Process__c branchProcess = Processes.generateOne(Branch.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'the-chain');
        insert chain;

        //arrange steps
        ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, branchProcess.Id);

        boolean expectedPageReferenceUrlFlag = true;

        // Act
        ApexPages.StandardController controller = new ApexPages.StandardController(chainStep);
        ChainStepExtensionConfigure chainStepExtensionConfigure = new ChainStepExtensionConfigure( controller );
        
        // Prepare
        String actualUrl = chainStepExtensionConfigure.initConfig().getUrl();
        String expectedUrl = String.valueOf(chainStep.Id).left(15);

        // Assert
        System.assert(actualUrl.contains(expectedUrl));
    }
}