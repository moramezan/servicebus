public with sharing class SequenceListExtension {
    
    public SequenceListExtension(ApexPages.StandardSetController controller) {
        //
    }

    public Integer getLiveVersion() {
        return Integer.valueOf(BrokerSetting__c.getOrgDefaults().Version__c);
    }
    
    static public Integer getDraftVersion() {
        return SequenceSetModel.draftVersion();
    }
    
    static public List<Integer> getRunnableVersions() {
        Set<Integer> versions = new Set<Integer>();
        for (Step__c step : Step__c.getAll().values()) if (!step.IsDraft__c) versions.add(step.Version__c.intValue());
        
        List<Integer> runnableVersions = new List<Integer>(versions);
        runnableVersions.sort();
        return runnableVersions;
    }
    
    @Future static public void ChangeVersion(Integer version) {
        if (version == null) version = 1;
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
        setting.Version__c = version;
        upsert setting;
    }
    
    @ReadOnly @RemoteAction static public void ChooseVersion(Integer version) {
        ChangeVersion(version);
    }
}