public with sharing class MonitorController {
    
    public class Statistic {
        public Statistic(String route, Integer paused, Integer queued, Integer started, Integer exceptions) {
            this.Route = route;
            this.Paused = paused;
            this.Queued = queued;
            this.Started = started;
            this.Exceptions = exceptions;
            
            this.Jobs = 0;
            this.Job = null;
        }
        
        public String Route {get; set;}
        public Integer Paused {get; set;}
        public Integer Queued {get; set;}
        public Integer Started {get; set;}
        public Integer Exceptions {get; set;}
        
        public Integer Jobs {get; set;}
        public List<AsyncApexJob> Job {get; set;}
    }
    
    @ReadOnly @RemoteAction static public List<Statistic> fetchTestStatistics() {
        return new List<Statistic>{
            new Statistic(null,               1, 32,  0,  0),
            new Statistic('AggregateByJobService',         2,  0,  0,  0),
            new Statistic('JumpService',         2,  0,  0,  0),
            new Statistic('PublishService',         1,  0,  4,  0),
            new Statistic('ScheduleService',            2,  0,  0,  0),
            new Statistic('SubscribeService',1,  0,  0,  0),
            new Statistic('TransactionService',     2,  0,  2,  0),
            new Statistic('TerminateService',       2,  0,  9,  0),
            new Statistic('WiretapService',       2,  0,  9,  0)
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
            ALL ROWS //#1134 shows some history
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
            WHERE Status__c = 'Queued'
            GROUP BY Route__c
        ]) {
            Statistic statistic = route2statistic.get((String)result.get('route')); //#761
            if (statistic == null) statistic = route2statistic.get(null);
            statistic.Queued += (Integer)result.get('total');
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
        
        //fake blue messages representing queueable jobs
        for (AggregateResult result : [
            SELECT COUNT(Id) total
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c
            AND ApexClass.Name = 'BrokerJob'
            AND JobType = 'Queueable' //#890
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ]) {
            Statistic statistic = route2statistic.get(null);
            statistic.Jobs += (Integer)result.get('total');
        }
        
        //glorified twirly representing broker batch
        Statistic statistic = route2statistic.get(null);
        statistic.Job = ApexDomain.get([
            SELECT Id
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c AND ApexClass.Name = 'BrokerBatch'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]);
        
        //pluck out the queued guys (null per #697)
        Statistic none = route2statistic.remove(null);
        List<String> stepNames = new List<String>(route2statistic.keySet());
        stepNames.sort();
        
        //sort queued then alphabetical
        List<Statistic> statistics = new List<Statistic>{none};
        for (String stepName : stepNames) statistics.add(route2statistic.get(stepName));
        return statistics;
    }
    
}