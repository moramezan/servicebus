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

        Process__c process = new   Process__c (   ApexClass__c = apexClass);
        insert process;

        ChainStep__c chainStep = new ChainStep__c ( Chain__c         =  chain.Id ,
                                                    Process__c       =  process.Id ,
                                                    Sequence__c      =  sequence);
        insert chainStep;
        
        chainStep = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :chainStep.Id];



        String expectedPageReferenceUrl = new PageReference('/' + chainStep.Configuration__c + '/e?retURL=' + chainStep.Id).getUrl();




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
        String  apexClass          = 'Branch';
        Decimal sequence           = 1;
        String  data               = 'data';



        Chain__c chain = new Chain__c( Name = chainName);
        insert chain;


        Process__c process = new   Process__c (   ApexClass__c = apexClass);
        insert process;

        ChainStep__c chainStep = new ChainStep__c ( Chain__c         =  chain.Id ,
                                                    Process__c       =  process.Id ,
                                                    Sequence__c      =  sequence);
        insert chainStep;

        boolean  expectedPageReferenceUrlFlag = true;

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