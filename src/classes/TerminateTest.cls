@IsTest //-- no view of org data
private class TerminateTest
{
    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Terminate.class);
        
        //assert
        Integer expectedLimits = 200; //max sync limit
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }

    static testmethod void withinSystemLimits() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'Terminate#1');
        insert sequence;
        
        Map<String,Object> inputEvent = new Map<String,Object>();
        inputEvent.put('Route', 'Terminate#1');
        
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Terminate.class);
        
        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.Service service = new Terminate();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
    }

}