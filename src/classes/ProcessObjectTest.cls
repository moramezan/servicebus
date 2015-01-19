@IsTest public class ProcessObjectTest { 
    
    public String Parameters;
    
    @TestVisible private class ESB {
        public String Tag = 'Fake';
        public String Name = 'Test';
        public String Description = 'Herpderp';
        public String Icon = null;
        public String HelpUrl = 'fakedocspage.html';
    }

    override public String toString() {
        return Json.serialize(new List<Map<String,Object>>());
    }

    static testmethod void callingGenerateOneInsertsExpectedProcess() {
        //arrange 
        List<Process__c> processesBefore = SalesforceObjectSet.listAll(Process__c.SObjectType);
        Integer actualProcessesBeforeCount = processesBefore.size();  

        //act  
        Process__c markProcess = ProcessObject.generateOne(Mark.class);
 
        //assemble
        List<Process__c> processesAfter = SalesforceObjectSet.listAll(Process__c.SObjectType);
        Integer actualProcessesAfterCount = processesAfter.size();
        
        //assert
        Integer expectedProcessesAfterCount = 1;
        Integer expectedProcessesBeforeCount = 0;
        
        System.assertEquals(expectedProcessesAfterCount , actualProcessesAfterCount);
        System.assertEquals(expectedProcessesBeforeCount, actualProcessesBeforeCount);
    }
    

    static testmethod void callingFromTypeReturnsProcessWithExpectedValues() {
        //arrange 
        Type actualType = Subscribe.class;
        
        Object process = actualType.newInstance();
        ProcessObject.ESB describeResult = (ProcessObject.ESB)Json.deserialize(Json.serialize(Subscribe.ESB.class.newInstance()), ProcessObject.ESB.class);
        String expectedName = describeResult.Name;
        String expectedTag = describeResult.Tag;
        String expectedDescription = describeResult.Description;
        Integer expectedLimits = describeResult.Limits;
        String expectedFullyQualifiedClassName = actualType.getName();
        Type innerClass = Type.forName(actualType.getName() + '.' + 'ESB'); 
        ProcessObject.ESB meta = (ProcessObject.ESB)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.ESB.class);
        String expectedStepConfig  = meta.StepConfig.getSObjectType().getDescribe().getName();
        String expectedIcon = meta.icon;
        String expectedHelpUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/apex/Csh?topic=ProcessPublishSubscribe';
        
        //act 
        Process__c subscribeProcess = ProcessObject.fromType(actualType);
        
        //assemble
        String actualName = subscribeProcess.Name; 
        String actualTag = subscribeProcess.Tag__c; 
        String actualDescription = subscribeProcess.Description__c; 
        String actualFullyQualifiedClassName = subscribeProcess.FullyQualifiedClassName__c; 
        String actualStepConfig = subscribeProcess.StepConfig__c; 
        String actualIcon = subscribeProcess.Icon__c; 
        String actualHelpUrl = subscribeProcess.HelpUrl__c;
        Integer actualLimits = (Integer)subscribeProcess.Limits__c;
        
        //assert
        System.assertEquals(expectedName , actualName );
        System.assertEquals(expectedTag , actualTag );
        System.assertEquals(expectedDescription , actualDescription );
        System.assertEquals(expectedFullyQualifiedClassName , actualFullyQualifiedClassName);
        System.assertEquals(expectedStepConfig , actualStepConfig);
        System.assertEquals(expectedIcon , actualIcon );
        System.assertEquals(expectedHelpUrl, actualHelpUrl);
        System.assertEquals(expectedLimits, actualLimits);
    } 
 
}