@IsTest public class StepSetModelTest {

    static testmethod void testToDtos() {
        //arrange step
        Step__c step = new Step__c(
            Name = 'Wiretaps#1',
            ConfigId__c = '015000000000000AAA',
            ConfigName__c = 'This step must be configured. Seriously.',
            ApexClassId__c = '01p000000000000AAA',
            ApexClassName__c = 'esb.Wiretap',
            Position__c = 1.0
        );
        
        step.SequenceName__c = 'Test';
        insert step;
        
        //arrange model
        List<Step__c> steps = new List<Step__c>{step};
        StepSetModel model = new StepSetModel(steps);
        
        //act
        List<Map<String,Object>> dtos = model.toDtos();
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = dtos.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedName = step.Name;
        String actualName = (String)dtos[0].get('Name');
        System.assertEquals(expectedName, actualName, 'Wrong Name.');
        
        String expectedConfigId = step.ConfigId__c;
        String actualConfigId = (String)dtos[0].get('ConfigId');
        System.assertEquals(expectedConfigId, actualConfigId, 'Wrong ConfigId.');
        
        String expectedConfigName = step.ConfigName__c;
        String actualConfigName = (String)dtos[0].get('ConfigName');
        System.assertEquals(expectedConfigName, actualConfigName, 'Wrong ConfigName.');
        
        String expectedApexClassId = step.ApexClassId__c;
        String actualApexClassId = (String)dtos[0].get('ApexClassId');
        System.assertEquals(expectedName, actualName, 'Wrong ApexClassId.');
        
        String expectedApexClassName = step.ApexClassName__c;
        String actualApexClassName = (String)dtos[0].get('ApexClassName');
        System.assertEquals(expectedApexClassName, actualApexClassName, 'Wrong ApexClassName.');
        
        Integer expectedPosition = step.Position__c.intValue();
        Integer actualPosition = (Integer)dtos[0].get('Position');
        System.assertEquals(expectedPosition, actualPosition, 'Wrong Position.');
    }

}