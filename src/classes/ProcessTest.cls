@isTest public class ProcessTest {

    static testMethod void callingGenerateOneInsertsExpectedProcess() {
        //arrange 
        List<Process__c> processesBefore = [SELECT Id, Name FROM Process__c];
        Integer actualProcessesBeforeCount = processesBefore.size();  

        //act  
        Process__c markProcess = Processes.generateOne(Mark.class);
 
        //assemble
        List<Process__c> processesAfter = [SELECT Id, Name FROM Process__c];
        Integer actualProcessesAfterCount = processesAfter.size();
        
        //assert
        Integer expectedProcessesAfterCount = 1;
        Integer expectedProcessesBeforeCount = 0;
        
        System.assertEquals(expectedProcessesAfterCount , actualProcessesAfterCount);
        System.assertEquals(expectedProcessesBeforeCount, actualProcessesBeforeCount);
    }
    

    static testMethod void callingFromTypeReturnsProcessWithExpectedValues() {
        //arrange 
        Type actualType = Subscribe.class;
        
        Process.Plugin plugin = (Process.Plugin)actualType.newInstance();
        Process.PluginDescribeResult describeResult = plugin.describe();
        String expectedName = describeResult.Name;
        String expectedTag = describeResult.Tag;
        String expectedDescription = describeResult.Description;
        String expectedFullyQualifiedClassName = actualType.getName();
        Type innerClass = Type.forName(actualType.getName() + '.' + 'Meta'); 
        Processes.Meta meta = (Processes.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), Processes.Meta.class);
        String expectedConfigObject = meta.ConfigObject.getSObjectType().getDescribe().getName();
        String expectedIcon = meta.icon;
        String expectedDocsPageUrl = Page.SubscribeHelp.getUrl();
        
        //act 
        Process__c process = Processes.fromType(actualType);
        
        //assemble
        String actualName = process.Name; 
        String actualTag = process.Tag__c; 
        String actualDescription = process.Description__c; 
        String actualFullyQualifiedClassName = process.FullyQualifiedClassName__c; 
        String actualConfigObject = process.ConfigObject__c; 
        String actualIcon = process.Icon__c; 
        String actualDocsPageUrl = process.DocsPageUrl__c;

        //assert
        System.assertEquals(expectedName , actualName );
        System.assertEquals(expectedTag , actualTag );
        System.assertEquals(expectedDescription , actualDescription );
        System.assertEquals(expectedFullyQualifiedClassName , actualFullyQualifiedClassName);
        System.assertEquals(expectedConfigObject , actualConfigObject);
        System.assertEquals(expectedIcon , actualIcon );
        System.assertEquals(expectedDocsPageUrl, actualDocsPageUrl);
    }    
}