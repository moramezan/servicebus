public with sharing class MonitorController {
    
    public Integer getLiveVersion() {
        return Integer.valueOf(BrokerSetting__c.getOrgDefaults().Version__c);
    }
    
    public Integer getDraftVersion() {
        Decimal draftVersion = (Decimal)[
            SELECT AVG(Version__c)
            FROM Step__c
            WHERE IsDraft__c = true
        ][0].get('expr0');
        
        return Integer.valueOf(draftVersion);
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
    
    @ReadOnly @RemoteAction static public List<Boolean> fetchJobs() {
        Boolean hasQueueableJobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :NamespaceSetting__c.getOrgDefaults().Prefix__c
            AND ApexClass.Name = 'Job'
            AND JobType IN ('Future', 'Queueable') //#890
            AND Status IN ('Queued', 'Processing', 'Preparing')
            LIMIT 1
        ].isEmpty();
        
        Boolean isBrokerRunning = Job.isScheduled() || Job.isRunning();
        
        return new List<Boolean>{
            isBrokerRunning, //red twirly
            hasQueueableJobs //grey twirly
        };
    }
    
    public class Statistic {
        public Statistic(String apexClassName, Integer paused, Integer buffered, Integer started, Integer exceptions) {
            this.ApexClassName = apexClassName;
            this.Paused = paused;
            this.Buffered = buffered;
            this.Started = started;
            this.Exceptions = exceptions;
        }
        
        public String ApexClassName {get; set;}
        public Integer Paused {get; set;}
        public Integer Buffered {get; set;}
        public Integer Started {get; set;}
        public Integer Exceptions {get; set;}
    }
    
    @ReadOnly @RemoteAction static public List<Statistic> fetchTestStatistics() {
        return new List<Statistic>{
            new Statistic(null,               1, 32,  0,  0),
            new Statistic('Branch',          1,  0,  0,  0),
            new Statistic('AggregateByEntryPoint',         2,  0,  0,  0),
            new Statistic('AggregateByJob',         2,  0,  0,  0),
            new Statistic('Jump',         2,  0,  0,  0),
            new Statistic('Publish',         1,  0,  4,  0),
            new Statistic('Schedule',            2,  0,  0,  0),
            new Statistic('Subscribe',1,  0,  0,  0),
            new Statistic('Subsequence',     2,  0,  2,  0),
            new Statistic('Terminate',       2,  0,  9,  0),
            new Statistic('Wiretap',       2,  0,  9,  0)
        };
    }
    
    @ReadOnly @RemoteAction static public List<Statistic> fetchStatistics() {
        Map<String,Statistic> route2statistic = new Map<String,Statistic>();
        
        //initialize empty statistics for each route
        for (AggregateResult result : [
            SELECT Route__c route
            FROM Message__c
            GROUP BY Route__c
        ]) {
            Statistic statistic = new Statistic((String)result.get('route'), 0, 0, 0, 0);
            route2statistic.put((String)result.get('route'), statistic);
        }
        
        //#761 add null guy for unrouted messages
        route2statistic.put(null, new Statistic(' ', 0, 0, 0, 0));
        
        //check for null so we don't blow up for unresolved messages
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Status__c) total
            FROM Message__c
            WHERE Status__c = 'Paused'
            GROUP BY Route__c
        ]) {
            Statistic statistic = route2statistic.get((String)result.get('route')); //#761
            if (statistic == null) statistic = route2statistic.get(null);
            statistic.Paused += (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Status__c) total
            FROM Message__c
            WHERE Status__c = 'Buffered'
            GROUP BY Route__c
        ]) {
            Statistic statistic = route2statistic.get((String)result.get('route')); //#761
            if (statistic == null) statistic = route2statistic.get(null);
            statistic.Buffered += (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Status__c) total
            FROM Message__c
            WHERE Status__c = 'Started' AND Exception__c = null
            GROUP BY Route__c
        ]) {
            Statistic statistic = route2statistic.get((String)result.get('route')); //#761
            if (statistic == null) statistic = route2statistic.get(null);
            statistic.Started += (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Status__c) total
            FROM Message__c
            WHERE Status__c = 'Started' AND Exception__c != null
            GROUP BY Route__c
        ]) {
            Statistic statistic = route2statistic.get((String)result.get('route')); //#761
            if (statistic == null) statistic = route2statistic.get(null);
            statistic.Exceptions += (Integer)result.get('total');
        }
        
        //pluck out the buffered guys (null per #697)
        Statistic none = route2statistic.remove(null);
        List<String> stepNames = new List<String>(route2statistic.keySet());
        stepNames.sort();
        
        //sort buffered then alphabetical
        List<Statistic> statistics = new List<Statistic>{none};
        for (String stepName : stepNames) statistics.add(route2statistic.get(stepName));
        return statistics;
    }
    
}