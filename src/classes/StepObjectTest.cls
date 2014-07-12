@IsTest public class StepObjectTest {
    
    static testmethod void testMoveStepBefore() {
        //arrange processes
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepObject.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        StepObject step = new StepObject(terminateStep);
        step.moveBefore(wiretapStep.Id);
        
        //assemble
        wiretapStep = (Step__c)SalesforceObject.getById(wiretapStep.Id);
        terminateStep = (Step__c)SalesforceObject.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
    static testmethod void testMoveStepAfter() {
        //arrange processes
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'StepTest');
        insert sequence;
        
        //arrange steps
        Step__c wiretapStep = StepObject.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //assert before state
        System.assertEquals(1, wiretapStep.Position__c);
        System.assertEquals(2, terminateStep.Position__c);
            
        //act
        StepObject step = new StepObject(wiretapStep);
        step.moveAfter(terminateStep.Id);
        
        //assemble
        wiretapStep = (Step__c)SalesforceObject.getById(wiretapStep.Id);
        terminateStep = (Step__c)SalesforceObject.getById(terminateStep.Id);
        
        //assert after state
        System.assertEquals(1, terminateStep.Position__c);
        System.assertEquals(2, wiretapStep.Position__c);
    }
    
}