@IsTest public class ProcessModelTest {
    
    public String Event;
    
    @TestVisible private class ESB {
        public String Tag = 'Fake';
        public String Name = 'Test';
        public String Description = 'Herpderp';
        public String Icon = null;
        public String HelpUrl = 'fakedocspage.html';
    }

    override public String toString() {
        System.assert(this.Event != null);
        return Json.serialize(new List<Map<String,Object>>());
    }

    static testmethod void callingFromTypeReturnsProcessWithExpectedValues() {
        //arrange
        Type actualType = Subscribe.class;
        
        Object process = actualType.newInstance();
        ProcessModel describeResult = (ProcessModel)Json.deserialize(Json.serialize(Subscribe.ESB.class.newInstance()), ProcessModel.class);
        String expectedName = describeResult.Name;
        String expectedTag = describeResult.Tag;
        String expectedDescription = describeResult.Description;
        Integer expectedLimits = describeResult.Limits;
        String expectedFullyQualifiedClassName = actualType.getName();
        Type innerClass = Type.forName(actualType.getName() + '.' + 'ESB');
        if (innerClass == null) innerClass = Type.forName(actualType.getName() + 'ESB');
        ProcessModel meta = (ProcessModel)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessModel.ESB.class);
        String expectedStepConfig  = meta.StepConfig;
        String expectedIcon = meta.icon;
        
        //act
        ProcessModel subscribeProcess = ProcessModel.fromFqcn(Subscribe.class.getName());
        
        //assemble
        String actualName = subscribeProcess.Name;
        String actualTag = subscribeProcess.Tag;
        String actualDescription = subscribeProcess.Description;
        String actualFullyQualifiedClassName = subscribeProcess.FullyQualifiedClassName;
        String actualStepConfig = subscribeProcess.StepConfig;
        String actualIcon = subscribeProcess.Icon;
        Integer actualLimits = (Integer)subscribeProcess.Limits;
        
        //assert
        System.assertEquals(expectedName , actualName );
        System.assertEquals(expectedTag , actualTag );
        System.assertEquals(expectedDescription , actualDescription );
        System.assertEquals(expectedFullyQualifiedClassName , actualFullyQualifiedClassName);
        System.assertEquals(expectedStepConfig , actualStepConfig);
        System.assertEquals(expectedIcon , actualIcon );
        System.assertEquals(expectedLimits, actualLimits);
    }
 
}