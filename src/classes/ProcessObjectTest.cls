@IsTest public class ProcessObjectTest { 
    
    public class Meta {
        public String Tag = 'Fake';
        public String Name = 'Test';
        public String Description = 'Herpderp';
        public String Icon = null;
        public String DocsPageUrl = 'fakedocspage.html';
    }

    public String Parameters;
    
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
        ProcessObject.Meta describeResult = (ProcessObject.Meta)Json.deserialize(Json.serialize(Subscribe.Meta.class.newInstance()), ProcessObject.Meta.class);
        String expectedName = describeResult.Name;
        String expectedTag = describeResult.Tag;
        String expectedDescription = describeResult.Description;
        String expectedFullyQualifiedClassName = actualType.getName();
        Type innerClass = Type.forName(actualType.getName() + '.' + 'Meta'); 
        ProcessObject.Meta meta = (ProcessObject.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.Meta.class);
        String expectedConfigObject = meta.ConfigObject.getSObjectType().getDescribe().getName();
        String expectedIcon = meta.icon;
        String expectedDocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.SubscribeHelp.getUrl();
        
        //act 
        Process__c subscribeProcess = ProcessObject.fromType(actualType);
        
        //assemble
        String actualName = subscribeProcess.Name; 
        String actualTag = subscribeProcess.Tag__c; 
        String actualDescription = subscribeProcess.Description__c; 
        String actualFullyQualifiedClassName = subscribeProcess.FullyQualifiedClassName__c; 
        String actualConfigObject = subscribeProcess.ConfigObject__c; 
        String actualIcon = subscribeProcess.Icon__c; 
        String actualDocsPageUrl = subscribeProcess.DocsPageUrl__c;

        //assert
        System.assertEquals(expectedName , actualName );
        System.assertEquals(expectedTag , actualTag );
        System.assertEquals(expectedDescription , actualDescription );
        System.assertEquals(expectedFullyQualifiedClassName , actualFullyQualifiedClassName);
        System.assertEquals(expectedConfigObject , actualConfigObject);
        System.assertEquals(expectedIcon , actualIcon );
        System.assertEquals(expectedDocsPageUrl, actualDocsPageUrl);
    } 
 
    static testmethod void processWithoutIconWillDefaultWithCogIcon() {
        //arrange 
        Type actualType = ProcessObjectTest.class;
        Object process = actualType.newInstance();
        
        Type innerClass = Type.forName(actualType.getName() + '.' + 'Meta'); 
        ProcessObject.Meta meta = (ProcessObject.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.Meta.class);

        //act 
        Process__c subscribeProcess = ProcessObject.fromType(actualType);
        
        //assemble
        String actualIcon = subscribeProcess.Icon__c; 

        //assert
        String expectedIcon = 'cog';
        System.assertEquals(expectedIcon , actualIcon);
    }
}