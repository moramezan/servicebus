public with sharing class SequenceListExtension {
    
    public SequenceListExtension(ApexPages.StandardSetController controller) {
        //
    }

    static public Integer getDraftVersion() {
        return SequenceSetModel.draftVersion();
    }
    
    static public Integer getLatestVersion() {
        return SequenceSetModel.latestVersion();
    }
    
    static public List<Integer> getRunnableVersions() {
        Set<Integer> versions = new Set<Integer>();
        for (Step__c step : Step__c.getAll().values()) if (!step.IsDraft__c) versions.add(step.Version__c.intValue());
        
        List<Integer> runnableVersions = new List<Integer>(versions);
        runnableVersions.sort();
        return runnableVersions;
    }
    
    @RemoteAction static public void ChangeVersion(Integer version) {
        if (version == null) System.assert(false, 'Null version!');
        Application__c application = Application__c.getOrgDefaults();
        application.BrokerVersion__c = version;
        upsert application;
    }
}