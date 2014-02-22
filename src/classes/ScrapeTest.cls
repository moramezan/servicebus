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
        //arrange processes
        Process__c scrapeProcess = Processes.generateOne(Scrape.class);
        
        //act
        String actualConfiguration = scrapeProcess.Configurable__c;
        
        // Assert
        String expectedConfiguration = Schema.SobjectType.ScrapeConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
    
    private static  testMethod void callingInvokeCreatesExpectedAttachment() {
        //arrange processes
        Process__c scrapeProcess = Processes.generateOne(Scrape.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'ScrapeChain');
        insert chain;
        
        //arrange steps
        Step__c step = Steps.generateOne(chain.Id, scrapeProcess.Id);
        Database.update(new ScrapeConfiguration__c(
            Id = step.ConfigurationId__c,
            Endpoint__c = endPoint
        ));
        
        Map<String,Object> parameters = new Map<String,Object>{'eda__configuration' => step.ConfigurationId__c};

        //act
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        Scrape plugin = new Scrape();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = Utility.convert(result);
        Test.stopTest();
        
        // Assemble
        List<Attachment> attachments = [
            SELECT id, Name, ParentId, Body
            FROM Attachment
            WHERE ParentId = :step.ConfigurationId__c
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