@IsTest public class StepModelTest {
    
    static testmethod void testMoveStepBefore() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        StepModel step = StepModel.fromId(terminateStep.Id);
        step.moveBefore(wiretapStep.Id);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        StepModel step = StepModel.fromId(wiretapStep.Id);
        step.moveAfter(terminateStep.Id);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
}