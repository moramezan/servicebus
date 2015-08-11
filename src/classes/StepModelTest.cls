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
        //arrange config
        Document document = new Document(Name = 'Test', FolderId = UserInfo.getUserId());
        insert document;
        
        //arrange step
        Step__c step = new Step__c(Name = 'Test#1', ConfigId__c = document.Id);
        insert step;
        
        //act
        StepModel model = StepModel.fromid(step.Id);
        PageReference view = model.showStepConfig();
        
        //assert
        String expectedId = document.Id;
        String actualId = view.getParameters().get('id');
        System.assertEquals(expectedId, actualId, 'Wrong id.');
        
        String expectedIsdtp = 'vw';
        String actualIsdtp = view.getParameters().get('isdtp');
        System.assertEquals(expectedIsdtp, actualIsdtp, 'Wrong isdtp.');
    }
    
}