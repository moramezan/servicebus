@IsTest public class StepModelTest {
    
    static testmethod void testMoveStepBefore() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c.intValue());
        System.assertEquals(2, terminateStep.Position__c.intValue());
            
        //act
        StepModel step = StepModel.fromName(terminateStep.Name);
        step.moveBefore(wiretapStep.Name);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c.intValue());
        System.assertEquals(2, wiretapStep.Position__c.intValue());
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c.intValue());
        System.assertEquals(2, terminateStep.Position__c.intValue());
            
        //act
        StepModel step = StepModel.fromName(wiretapStep.Name);
        step.moveAfter(terminateStep.Name);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c.intValue());
        System.assertEquals(2, wiretapStep.Position__c.intValue());
    }
    
    static testmethod void testShowStepConfig() {
        //arrange step
        Step__c step = new Step__c(Name = 'Test#1', ConfigId__c = '01524000000FuQh');
        insert step;
        
        //act
        StepModel model = StepModel.fromId(step.Id);
        PageReference view = model.showStepConfig();
        
        //assert
        String expectedUrl = '/01524000000FuQh?isdtp=vw';
        String actualUrl = view.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong url.');
    }
    
}