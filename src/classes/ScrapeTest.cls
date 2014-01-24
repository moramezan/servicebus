@isTest
public class ScrapeTest {
    
   private static string endPoint = 'http://a-site.com';
    
    
	public class MockHttpResponseGenerator implements HttpCalloutMock {
        // Implement this interface method
        public HTTPResponse respond(HTTPRequest req) {  
            String expectedEndpoint = endPoint;
            System.assertEquals(expectedEndpoint, req.getEndpoint());
            System.assertEquals('GET', req.getMethod());
            
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('some content');
            res.setStatusCode(200);
            return res;
        }
    } 
    
    
    private static  testMethod void canDetermineConfigurable () {
        //arrange
        String  className  = 'Scrape';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        
        //act
        String actualConfiguration = processes[0].Configurable__c;
        
        // Assert
        String expectedConfiguration = Schema.SobjectType.ScrapeConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);  
    }
    
    private static  testMethod void callingInvokeCreatesExpectedAttachment() {
        //arrange
        String  className  = 'Scrape';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
       	Process__c scrapeProcess = processes[0];
        insert processes;

        Chain__c chain = new Chain__c(Name = 'ScrapeChain');
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = scrapeProcess.Id);
        insert chainStep;
        
        ScrapeConfiguration__c configuration = [
            SELECT Id, Endpoint__c
            FROM ScrapeConfiguration__c
        ];
        configuration.Endpoint__c = endPoint;
        update configuration;

        Map<String,Object> notification = new Map<String,Object>{'eda__configuration' => configuration.Id};

        //act
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        Scrape plugin = new Scrape();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> results = Utility.convert(result);
    	Test.stopTest();
        
       	// Assemble
        List<Attachment> attachments = [
            SELECT id, Name, ParentId, Body
            FROM Attachment 
            WHERE ParentId = :configuration.Id
        ];
        
        String actualBody = '';
        if (attachments.size() > 0) {
           actualBody = attachments[0].Body.toString();
        }

        // Assert
        String expectedBody = 'some content';
        System.assertEquals(expectedBody, actualBody);  
    }    
}