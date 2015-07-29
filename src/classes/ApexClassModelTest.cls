@IsTest public class ApexClassModelTest {
    
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
        ApexClassModel.ESB describeResult = (ApexClassModel.ESB)Json.deserialize(Json.serialize(Subscribe.ESB.class.newInstance()), ApexClassModel.ESB.class);
        String expectedName = describeResult.Name;
        String expectedTag = describeResult.Tag;
        String expectedDescription = describeResult.Description;
        Integer expectedLimits = describeResult.Limits;
        String expectedFullyQualifiedClassName = actualType.getName();
        Type innerClass = Type.forName(actualType.getName() + '.' + 'ESB');
        if (innerClass == null) innerClass = Type.forName(actualType.getName() + 'ESB');
        ApexClassModel.ESB meta = (ApexClassModel.ESB)Json.deserialize(Json.serialize(innerClass.newInstance()), ApexClassModel.ESB.class);
        String expectedStepConfig  = meta.StepConfig;
        String expectedIcon = meta.icon;
        
        //act
        ApexClassModel subscribeProcess = new ApexClassModel(Subscribe.class);
        
        //assemble
        String actualName = subscribeProcess.model.Name;
        String actualTag = subscribeProcess.model.Tag;
        String actualDescription = subscribeProcess.model.Description;
        String actualFullyQualifiedClassName = subscribeProcess.model.FullyQualifiedClassName;
        String actualStepConfig = subscribeProcess.model.StepConfig;
        String actualIcon = subscribeProcess.model.Icon;
        Integer actualLimits = (Integer)subscribeProcess.model.Limits;
        
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