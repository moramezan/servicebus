@isTest public class StepTest {
    
    static testMethod void testMoveStepBefore() {
        //arrange processes
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepSet.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepSet.generateOne(sequence.Id, terminateProcess.Id);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        Step step = new Step(terminateStep);
        step.moveBefore(wiretapStep.Id);
        
        //assemble
        wiretapStep = (Step__c)SalesforceObject.getById(wiretapStep.Id);
        terminateStep = (Step__c)SalesforceObject.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
    static testMethod void testMoveStepAfter() {
        //arrange processes
        Process__c wiretapProcess = ProcessSet.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepSet.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepSet.generateOne(sequence.Id, terminateProcess.Id);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        Step step = new Step(wiretapStep);
        step.moveAfter(terminateStep.Id);
        
        //assemble
        wiretapStep = (Step__c)SalesforceObject.getById(wiretapStep.Id);
        terminateStep = (Step__c)SalesforceObject.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
}