@IsTest public class ConfigStepExtensionTest {

    static testmethod void testRedirectOccurs() {
        //arrange process, sequence and step
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);
        
        JumpConfig__c config = new JumpConfig__c();
        ApexPages.StandardController controller = new ApexPages.StandardController(config);
        ConfigStepExtension extension = new ConfigStepExtension(controller);
        
        //act
        PageReference redirect = extension.doRedirect();
        
        //assert
        String id = String.valueOf(terminateStep.Id).left(15);
        System.assert(redirect.getUrl().contains(id));
    }

}