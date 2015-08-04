public with sharing class RemoteSiteSettingController {
    
    /**
     * This does appear in the Visualforce Component if they view
     * the source quickly enough, but just trying our damndest to
     * keep the new sauce "secret".
     */
    public String getDeployXml() {
        Organization organization = [SELECT InstanceName FROM Organization WHERE Id = :UserInfo.getOrganizationId() LIMIT 1]; //#112 pass security scanner for 34.0 release
        return ''
            + '<?xml version="1.0" encoding="utf-8"?>'
            + '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            + '<env:Header>'
            + '<urn:SessionHeader xmlns:urn="http://soap.sforce.com/2006/04/metadata">'
            + '<urn:sessionId>' + UserInfo.getSessionId() + '</urn:sessionId>'
            + '</urn:SessionHeader>'
            + '</env:Header>'
            + '<env:Body>'
            + '<upsertMetadata xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '<metadata xsi:type="RemoteSiteSetting">'
            + '<fullName>' + organization.InstanceName + '_Salesforce</fullName>'
            + '<description>' + organization.InstanceName + '_Salesforce</description>'
            + '<disableProtocolSecurity>false</disableProtocolSecurity>'
            + '<isActive>true</isActive>'
            + '<url>' + OAuthSetting__c.getOrgDefaults().InstanceUrl__c + '</url>'
            + '</metadata>'
            + '<metadata xsi:type="RemoteSiteSetting">'
            + '<fullName>' + organization.InstanceName + '_Visualforce</fullName>'
            + '<description>' + organization.InstanceName + '_Visualforce</description>'
            + '<disableProtocolSecurity>false</disableProtocolSecurity>'
            + '<isActive>true</isActive>'
            + '<url>' + Url.getSalesforceBaseUrl().toExternalForm().replace('esb', 'c') + '</url>'
            + '</metadata>'
            + '</upsertMetadata>'
            + '</env:Body>'
            + '</env:Envelope>'
        ;
    }
}