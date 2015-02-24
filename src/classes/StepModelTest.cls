@IsTest public class StepModelTest {
    
    static testmethod void testMoveStepBefore() {
        //arrange processes
        Process__c wiretapProcess = ProcessModel.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepModel.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        StepModel step = new StepModel(terminateStep);
        step.moveBefore(wiretapStep.Id);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange processes
        Process__c wiretapProcess = ProcessModel.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepModel.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        StepModel step = new StepModel(wiretapStep);
        step.moveAfter(terminateStep.Id);
        
        //assemble
        wiretapStep = (Step__c)ApexDomain.getById(wiretapStep.Id);
        terminateStep = (Step__c)ApexDomain.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
}