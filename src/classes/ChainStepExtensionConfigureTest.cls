@isTest  //-- no view of org data
private  class ChainStepExtensionConfigureTest {
    static testMethod void callingInitConfigWhenConfigurationIdNotNullReturnsExpectedUrl() {
        // Arrange :
        String chainName = 'the-chain';
        String apexClass = 'Branch'; // must be a real class that implements Configurable
        Decimal sequence = 1;
        String data = 'data';

        Chain__c chain = new Chain__c( Name = chainName);
        insert chain;

        List<String> names = new List<String>{apexClass};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
            procecessNameToProcess.put(p.Name, p); 
        }
        Process__c process =  (Process__c )procecessNameToProcess.get(apexClass);

        ChainStep__c chainStep = new ChainStep__c (
            Chain__c = chain.Id ,
            Process__c = process.Id ,
            Sequence__c = sequence
        );
        insert chainStep;
        
        chainStep = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :chainStep.Id];

        String expectedPageReferenceUrl = new PageReference('/' + chainStep.Configuration__c + '/e?retURL=' + chainStep.Id).getUrl();

        // Act
        ApexPages.StandardController controller = new ApexPages.StandardController(chainStep);
        ChainStepExtensionConfigure chainStepExtensionConfigure = new ChainStepExtensionConfigure( controller );
        String actualPageReferenceUrl = chainStepExtensionConfigure.initConfig().getUrl();

        // Assert
        System.assertEquals(expectedPageReferenceUrl , actualPageReferenceUrl );
        /////// expectedPageReferenceUrl=[ /null/e?retURL=a02b0000008Ewn5AAC ], actualPageReferenceUrl=[ /a02b0000008Ewn5 ]
    }

    static testMethod void callingInitConfigWhenConfigurationIdIsNullReturnsExpectedUrl() {
        // Arrange :
        String chainName = 'the-chain';
        String apexClass = 'Branch';
        Decimal sequence = 1;
        String data = 'data';

        Chain__c chain = new Chain__c( Name = chainName);
        insert chain;

        Process__c process = new Process__c (Name = apexClass);
        insert process;

        ChainStep__c chainStep = new ChainStep__c(
            Chain__c = chain.Id,
            Process__c = process.Id,
            Sequence__c = sequence
        );
        insert chainStep;

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