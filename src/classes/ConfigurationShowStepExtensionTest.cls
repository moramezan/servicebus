@IsTest public class ConfigurationShowStepExtensionTest {

    static testMethod void testRedirectOccurs() {
        //arrange process, sequence and step
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c terminateStep = StepSet.generateOne(sequence.Id, terminateProcess.Id);
        
        JumpConfiguration__c configuration = new JumpConfiguration__c();
        ApexPages.StandardController controller = new ApexPages.StandardController(configuration);
        ConfigurationShowStepExtension extension = new ConfigurationShowStepExtension(controller);
        
        //act
        PageReference redirect = extension.doRedirect();
        
        //assert
        String id = String.valueOf(terminateStep.Id).left(15);
        System.assert(redirect.getUrl().contains(id));
    }

}