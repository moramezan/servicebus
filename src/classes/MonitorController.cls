public with sharing class MonitorController {
    
    @ReadOnly @RemoteAction static public List<Boolean> fetchJobs() {
        Boolean hasQueueableJobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c
            AND ApexClass.Name = 'Job'
            AND JobType IN ('Future', 'Queueable') //#890
            AND Status IN ('Queued', 'Processing', 'Preparing')
            LIMIT 1
        ].isEmpty();
        
        Boolean isBrokerRunning = Enqueue.isScheduled() || Enqueue.isRunning();
        
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
            LIMIT 1000000 //checkmarx readonly
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