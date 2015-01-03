public with sharing class MonitorController {
    
    //eg "ns."
    public String getApexNamespacePrefix() {
        return MonitorController.class.getName().substringBefore('MonitorController');
    }
    
    public class Statistic {
        public Statistic(String name, Integer queued, Integer buffered, Integer started, Integer rebuffered, Integer overdue) {
            this.Name = name;
            this.Queued = queued;
            this.Buffered = buffered;
            this.Started = started;
            this.Rebuffered = rebuffered;
            this.Overdue = overdue;
        }
        
        public String Name {get; set;}
        public Integer Queued {get; set;}
        public Integer Buffered {get; set;}
        public Integer Started {get; set;}
        public Integer Rebuffered {get; set;}
        public Integer Overdue {get; set;}
    }
    
    @RemoteAction static public List<Statistic> getTestStatistics() {
        return new List<Statistic>{
            new Statistic('Branch',          1,  1,  0,  0,  0),
            new Statistic('Publish',         2, 14,  0,  0,  0),
            new Statistic('Wiretap',         1,  1,  4,  0,  0),
            new Statistic('Jump',            2,  1,  0,  0,  0),
            new Statistic('AuditInitializer',1,  1,  0,  0,  0),
            new Statistic('Subsequence',     2,  1,  2,  0,  0),
            new Statistic('Subscribe',       2, 14,  9,  0,  0),
            new Statistic('Schedule',        1,  1,  0,  0,  0),
            new Statistic('AuditWriter',       0,  1,  0,  0,  0),
            new Statistic('Gate',            1,  1,  0,  0,  0),
            new Statistic('Scrape',          0,  0, 44,  0, 44),
            new Statistic('Mark',            0,  1,  0,  0,  0)
        };
    }
    
    @RemoteAction static public List<Statistic> getStatistics() {
        //we need to be able to populate the scattered statuses by process id
        Map<String,Statistic> route2statistic = new Map<String,Statistic>();
        
        List<Step__c> steps = [
            SELECT Id, Name, Process__c, Process__r.Name
            FROM Step__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        //populate id-keyed map for each process
        for (Step__c step : steps) {
            Statistic statistic = new Statistic(step.Process__r.Name, 0, 0, 0, 0, 0);
            route2statistic.put(step.Name, statistic);
        }
        
        //check for null so we don't blow up for unresolved messages
        //TODO is there any point even displaying queued messages?!?!
        //TODO restore after #662
        //first aggregate by route
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Status__c) total
            FROM Message__c
            WHERE Route__c != null
            AND Status__c = 'Queued'
            GROUP BY Route__c
        ]) {
            route2statistic.get((String)result.get('route')).Queued = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Status__c) total
            FROM Message__c
            WHERE Route__c != null
            AND Status__c = 'Buffered'
            GROUP BY Route__c
        ]) {
            route2statistic.get((String)result.get('route')).Buffered = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Status__c) total
            FROM Message__c
            WHERE Route__c != null
            AND Status__c = 'Started'
            GROUP BY Route__c
        ]) {
            route2statistic.get((String)result.get('route')).Started = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Status__c) total
            FROM Message__c
            WHERE Route__c != null
            AND Status__c = 'Rebuffered'
            GROUP BY Route__c
        ]) {
            route2statistic.get((String)result.get('route')).Rebuffered = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Route__c route, COUNT(Id) total
            FROM Message__c
            WHERE Route__c != null
            AND IsOverdue__c = true
            GROUP BY Route__c
        ]) {
            route2statistic.get((String)result.get('route')).Overdue = (Integer)result.get('total');
        }
        
        //second collate routes into processes via steps
        Map<String,Statistic> process2statistic = new Map<String,Statistic>();
        
        List<Process__c> processes = [
            SELECT Id, Name
            FROM Process__c
            LIMIT 1000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        for (Process__c process : processes) {
            Statistic statistic = new Statistic(process.Name, 0, 0, 0, 0, 0);
            process2statistic.put(process.Name, statistic);
        }
        
        Map<String,String> route2process = new Map<String,String>();
        for (Step__c step : steps) route2process.put(step.Name, step.Process__r.Name);
        
        //combine first and second parts
        for (String route : route2statistic.keySet()) {
            Statistic routeStat = route2statistic.get(route);
            String process = route2process.get(route);
            
            Statistic procStat = process2statistic.get(process);
            procStat.Queued     += routeStat.Queued;
            procStat.Buffered   += routeStat.Buffered;
            procStat.Started    += routeStat.Started;
            procStat.Rebuffered += routeStat.Rebuffered;
            procStat.Overdue    += routeStat.Overdue;
        }
        
        return process2statistic.values();
    }
    
}