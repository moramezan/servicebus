public with sharing class RemoteSiteSettingController {
    
    /**
     * Determines if a Remote Site Setting exists for the API hostname of this org.
     * eg true (you can interrogate APIs from Apex)
     * eg false (we must deploy Remote Site Setting)
     */
    static public Boolean isRssPresent {
        get {
            if (isRssPresent == null) {
                //memoize
                HttpRequest request = new HttpRequest();
                request.setEndpoint(protocolAndHost);
                request.setMethod('GET');
                
                try {
                    new Http().send(request);
                    isRssPresent = true;
                } catch (CalloutException e) {
                    //probably 'Unauthorized endpoint'
                    isRssPresent = false;
                }
            }
            
            return isRssPresent;
        }
    }
    
    /**
     * Determines the true API hostname for a Salesforce org using the Identity API.
     * eg 'https://pod.salesforce.com' (most orgs)
     * eg 'https://custom.my.salesforce.com' (my domain)
     * eg 'https://custom--dev.pod.my.salesforce.com' (sandbox orgs)
     */
    static public String protocolAndHost {
        get {
            if (protocolAndHost == null) {
                //memoize
                String orgId = UserInfo.getOrganizationId();
                String userId = UserInfo.getUserId();
                PageReference pr = new PageReference('/id/' + orgId + '/' + userId);
                pr.getParameters().put('oauth_token', UserInfo.getSessionId());
                pr.getParameters().put('format', 'json');
                
                //within test context use url class, else derive from identity api
                String data = Test.isRunningTest() ? '{"urls": {"rest": "' + Url.getSalesforceBaseUrl().toExternalForm() + '"}}' : pr.getContent().toString();
                Map<String,Object> result = (Map<String,Object>)Json.deserializeUntyped(data);
                Map<String,Object> urls = (Map<String,Object>)result.get('urls');
                Url rest = new Url((String)urls.get('rest'));
                protocolAndHost = rest.getProtocol() + '://' + rest.getHost();
            }
            
            return protocolAndHost;
        }
    }
    
    public String getDeployXml() {
        return ''
            + '<?xml version="1.0" encoding="utf-8"?>'
            + '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            + '<env:Header>'
            + '<urn:SessionHeader xmlns:urn="http://soap.sforce.com/2006/04/metadata">'
            + '<urn:sessionId>' + UserInfo.getSessionId() + '</urn:sessionId>'
            + '</urn:SessionHeader>'
            + '</env:Header>'
            + '<env:Body>'
            + '<createMetadata xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '<metadata xsi:type="RemoteSiteSetting">'
            + '<fullName>Enterprise_Service_Bus_API</fullName>'
            + '<description>Enterprise Service Bus API</description>'
            + '<disableProtocolSecurity>false</disableProtocolSecurity>'
            + '<isActive>true</isActive>'
            + '<url>' + protocolAndHost + '</url>'
            + '</metadata>'
            + '</createMetadata>'
            + '</env:Body>'
            + '</env:Envelope>'
        ;
    }
}