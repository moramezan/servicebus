@isTest private class ApiTest {


    
    //22:37:39.308 (308473000)|CALLOUT_REQUEST|[2384]|<?xml version="1.0" encoding="UTF-8"?><env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><env:Header><SessionHeader xmlns="urn:tooling.soap.sforce.com"><sessionId>00Db0000000d6mj!AQwAQLrOdG9aPfTI5gURaiNna1XRe0M8zLHYLbz5WcU7VqYYMtw0l4i81GDdtKyPmkNu90dlPWwZIIDhTA2e9cViG5ZyFtqu</sessionId></SessionHeader></env:Header><env:Body><query xmlns="urn:tooling.soap.sforce.com"><queryString>SELECT Id FROM CustomField WHERE DeveloperName = 'NumberOfLocations'</queryString></query></env:Body></env:Envelope>
    //22:37:39.308 (308539000)|CALLOUT_REQUEST|[2384]|query_element:[apex_schema_type_info=(urn:tooling.soap.sforce.com, true, false), field_order_type_info=(queryString), queryString=SELECT Id FROM CustomField WHERE DeveloperName = 'NumberOfLocations', queryString_type_info=(queryString, urn:tooling.soap.sforce.com, null, 1, 1, false)]::SFDC_STACK_DEPTH=1 SOAPAction="" User-Agent=SFDC-Callout/29.0 Accept=text/xml Content-Type=text/xml; charset=UTF-8 
    //22:37:40.014 (1014190000)|CALLOUT_RESPONSE|[2384]|<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="urn:tooling.soap.sforce.com" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Body><queryResponse><result><done>true</done><entityTypeName>CustomFieldDefinition</entityTypeName><queryLocator xsi:nil="true"/><records xsi:type="CustomField"><Id>00Nb0000007p4tGEAQ</Id></records><records xsi:type="CustomField"><Id>00Nb0000007p4tSEAQ</Id></records><size>2</size><totalSize>2</totalSize></result></queryResponse></soapenv:Body></soapenv:Envelope>
    public class QueryMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName, String responseNS, String responseName, String responseType) {
            Api.queryResponse_element responseElement = new Api.queryResponse_element();
            responseElement.result = new Api.QueryResult();
            responseElement.result.records = new List<Api.sObject_x>{new Api.sObject_x()};
            response.put('response_x', responseElement);
        }
    }
    
    static testMethod void coverQuery() {
        Test.setMock(WebServiceMock.class, new QueryMock());
        Object result = new Api.Client().query('SELECT Id FROM CustomField WHERE DeveloperName = \'NumberOfLocations\'');
        System.assert(result instanceof Api.QueryResult);
    }
  
    //17:24:30.514 (514517000)|CALLOUT_REQUEST|[2471]|<?xml version="1.0" encoding="UTF-8"?><env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><env:Header><SessionHeader xmlns="urn:tooling.soap.sforce.com"><sessionId>00Db0000000d6mj!AQwAQOsEgWb60aKf1rtPw8w7VwwpvgHMsmyzDqlHtde1nz3NIpAgaXdTQcq0Y_I7nkUoM206qHd79kCphCbajpd3cYwdfQx4</sessionId></SessionHeader></env:Header><env:Body><executeAnonymous xmlns="urn:tooling.soap.sforce.com"><String>System.debug(false);</String></executeAnonymous></env:Body></env:Envelope>
    //17:24:30.514 (514587000)|CALLOUT_REQUEST|[2471]|executeAnonymous_element:[String_x=System.debug(false);, String_x_type_info=(String, urn:tooling.soap.sforce.com, null, 1, 1, false), apex_schema_type_info=(urn:tooling.soap.sforce.com, true, false), field_order_type_info=(String_x)]::SFDC_STACK_DEPTH=1 SOAPAction="" User-Agent=SFDC-Callout/29.0 Accept=text/xml Content-Type=text/xml; charset=UTF-8 
    //17:24:30.643 (643538000)|CALLOUT_RESPONSE|[2471]|<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="urn:tooling.soap.sforce.com" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Body><executeAnonymousResponse><result><column>-1</column><compileProblem xsi:nil="true"/><compiled>true</compiled><exceptionMessage xsi:nil="true"/><exceptionStackTrace xsi:nil="true"/><line>-1</line><success>true</success></result></executeAnonymousResponse></soapenv:Body></soapenv:Envelope>
    public class ExecuteAnonymousMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName, String responseNS, String responseName, String responseType) {
            Api.executeAnonymousResponse_element responseElement = new Api.executeAnonymousResponse_element();
            responseElement.result = new Api.ExecuteAnonymousResult();
            response.put('response_x', responseElement);
        }
    }
    
    static testMethod void coverExecuteAnonymous() {
        Test.setMock(WebServiceMock.class, new ExecuteAnonymousMock());
        Object result = new Api.Client().executeAnonymous('System.debug(true);');
        System.assert(result instanceof Api.ExecuteAnonymousResult);
    }
  
}