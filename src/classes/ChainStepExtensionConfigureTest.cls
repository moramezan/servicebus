@isTest  //-- no view of org data
private  class ChainStepExtensionConfigureTest
{

    static testMethod void callingInitConfigWhenConfigurationIdNotNullReturnsExpectedUrl()
    {
        // Arrange :
        String  chainName          = 'the-chain';
        String  apexClass          = 'Branch';    // must be a real class that implements Configurable
        Decimal sequence           = 1;
        String  data               = 'data';



        Chain__c chain = new Chain__c( Name = chainName);
        insert chain;

        BranchConfiguration__c branchConfiguration = new BranchConfiguration__c(Chain__c = chain.Id);
        insert branchConfiguration;

        Process__c process = new   Process__c (   ApexClass__c = apexClass);
        insert process;

        ChainStep__c chainStep = new ChainStep__c ( Chain__c         =  chain.Id ,
                                                    Configuration__c =  branchConfiguration.Id,
                                                    Process__c       =  process.Id ,
                                                    Sequence__c      =  sequence);
        insert chainStep;



        String expectedPageReferenceUrl = new PageReference('/' + branchConfiguration.Id + '/e?retURL=' + chainStep.Id).getUrl();




        // Act
        ApexPages.StandardController controller = new ApexPages.StandardController(chainStep);
        ChainStepExtensionConfigure chainStepExtensionConfigure = new ChainStepExtensionConfigure( controller );
        String actualPageReferenceUrl  =  chainStepExtensionConfigure.initConfig().getUrl();



        // Assert
        System.assertEquals(expectedPageReferenceUrl , actualPageReferenceUrl );
    }


    static testMethod void callingInitConfigWhenConfigurationIdIsNullReturnsExpectedUrl()
    {
        // Arrange :
        String  chainName          = 'the-chain';
        String  apexClass          = 'branch';
        Decimal sequence           = 1;
        String  data               = 'data';



        Chain__c chain = new Chain__c( Name = chainName);
        insert chain;


        Id branchConfigurationId = null;

        Process__c process = new   Process__c (   ApexClass__c = apexClass);
        insert process;

        ChainStep__c chainStep = new ChainStep__c ( Chain__c         =  chain.Id ,
                                                    Configuration__c =  branchConfigurationId,
                                                    Process__c       =  process.Id ,
                                                    Sequence__c      =  sequence);
        insert chainStep;

        boolean  expectedPageReferenceUrlFlag = true;

        // Act
        ApexPages.StandardController controller = new ApexPages.StandardController(chainStep);
        ChainStepExtensionConfigure chainStepExtensionConfigure = new ChainStepExtensionConfigure( controller );
         String actualPageReferenceUrl  =  chainStepExtensionConfigure.initConfig().getUrl();

        // Prepare
         boolean  actualPageReferenceUrlFlag  = actualPageReferenceUrl.contains('/e?retURL=' + chainStep.Id);

        // Assert
        System.assertEquals( expectedPageReferenceUrlFlag , actualPageReferenceUrlFlag );
    }



}