public with sharing class OAuthController {
    
    final static private String CLIENT = '3MVG9fMtCkV6eLhfxsgy.rM62VU0VV56FOOkj0Tsgj1CavTLb3N.g2kuagIqfQiJ5hZJgJT0JrZKvsBKk_s1J';
    final static private String SECRET = '2834415504471774418';
    final static private String REDIRECT = 'https://login.salesforce.com/apex/esb__OAuth';
    
    public class Token {
        public String id;
        public String issued_at;
        public String scope;
        public String instance_url;
        public String token_type;
        public String refresh_token;
        public String id_token;
        public String signature;
        public String access_token;
    }
    
    /**
     * STEP ONE:
     * A human begins the OAuth dance from a link, eg:
     * https://login.salesforce.com/services/oauth2/authorize
     * ?client_id=3MVG98XJQQAccJQd0q2.s_Ak1RI4Of5e5kbUbbDYvVs41Ba0bFlnad4pzSMri5oQGHlDulk9raTGKF_y4lL51
     * &redirect_uri=https%3A%2F%2Flogin.salesforce.com%2Fapex%2Feda__OAuth
     * &response_type=code
     */
    public PageReference buildAuthLink() {
        PageReference pr = new PageReference('https://login.salesforce.com/services/oauth2/authorize');
        pr.getParameters().put('response_type', 'code');
        pr.getParameters().put('client_id', CLIENT);
        pr.getParameters().put('redirect_uri', REDIRECT);
        return pr;
    }
    
    /**
     * STEP TWO:
     * After clicking and choosing 'Allow' the human is redirected to this
     * visualforce callback page, which receives the token off the URL, eg:
     * https://login.salesforce.com/apex/esb__OAuth
     * ?code=aPrxHLAg3XMmPXtX1cG.hBCXhs8h5Wli7kDvSxAKd5kEvZ1Fkz3bPK3Jw82iI41iYhs6rk5iIA==
     * 
     * Then we perform an out-of-band request with our secret, eg:
     * https://login.salesforce.com/services/oauth2/token
     * ?client_id=3MVG9fMtCkV6eLhfxsgy.rM62VU0VV56FOOkj0Tsgj1CavTLb3N.g2kuagIqfQiJ5hZJgJT0JrZKvsBKk_s1J
     * &client_secret=2834415504471774418
     * &code=aPrxHLAg3XMmPXtX1cG.hBCXhkPQ89rfuQTvHhmuu16Jm.DL5lYIjdeGFLdNIh0OGO17V2QD3A%3D%3D
     * &format=json
     * &grant_type=authorization_code
     * &redirect_uri=https%3A%2F%2Flogin.salesforce.com%2Fapex%2Fesb__OAuth
     */
    public PageReference buildCodeLink(String code) {
        PageReference pr = new PageReference(ConfigureController.protocolAndHost + '/services/oauth2/token');
        pr.getParameters().put('grant_type', 'authorization_code');
        pr.getParameters().put('client_id', CLIENT);
        pr.getParameters().put('client_secret', SECRET);
        pr.getParameters().put('redirect_uri', REDIRECT);
        pr.getParameters().put('code', code);
        pr.getParameters().put('format', 'json');
        return pr;
    }
    
    public PageReference handleRedirect() {
        if (!RemoteSiteSettingController.isRssPresent) {
            //STEP ZERO (let component javascript deploy remote site setting)
            return null;
        }
        
        OAuthSetting__c setting = OAuthSetting__c.getOrgDefaults();
        if (setting == null) setting = new OAuthSetting__c();
        String code = ApexPages.currentPage().getParameters().get('code');
        
        if (code == null) {
            //STEP ONE
            PageReference authLink = this.buildAuthLink();
            
            //set retURL cookie because we can't pass it in connected app callback
            String retURL = ApexPages.currentPage().getParameters().get('retURL');
            authLink.setCookies(new List<Cookie>{new Cookie('retURL', retURL, null, -1, false)});
            
            //redirect to OAuth prompt
            return authLink;
        }
        
        if (code != null) {
            //STEP TWO
            PageReference codeLink = this.buildCodeLink(code);
            HttpRequest request = new HttpRequest();
            request.setMethod('POST');
            request.setEndpoint(codeLink.getUrl());
            
            String data = new Http().send(request).getBody();
            Token t = (Token)Json.deserialize(data, Token.class);
            setting.AccessToken__c = t.access_token;
            setting.RefreshToken__c = t.refresh_token;
            upsert setting;
            
            //get retURL from cookie because we can't pass it in connected app
            Cookie retURL = ApexPages.currentPage().getCookies().get('retURL');
            return retURL != null ? new PageReference(retURL.getValue()) : Page.Configure;
        }
        
        //never gets here
        return null;
    }
}