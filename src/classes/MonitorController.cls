public with sharing class MonitorController {
    
    //eg "ns."
    public String getApexNamespacePrefix() {
        return MonitorController.class.getName().substringBefore('MonitorController');
    }
    
    public class Statistic {
        public Statistic(String name, Integer queued, Integer buffered, Integer started, Integer rebuffered, Integer overdue) {
            this.FullyQualifiedClassName = name;
            this.Queued = queued;
            this.Buffered = buffered;
            this.Started = started;
            this.Rebuffered = rebuffered;
            this.Overdue = overdue;
        }
        
        public String FullyQualifiedClassName {get; set;}
        public Integer Queued {get; set;}
        public Integer Buffered {get; set;}
        public Integer Started {get; set;}
        public Integer Rebuffered {get; set;}
        public Integer Overdue {get; set;}
    }
    
    @RemoteAction static public List<Statistic> getTestStatistics() {
        return new List<Statistic>{
            new Statistic(' ',               1, 32,  0,  0,  0),
            new Statistic('Branch',          1,  0,  0,  0,  0),
            new Statistic('Publish',         2,  0,  0,  0,  0),
            new Statistic('Wiretap',         1,  0,  4,  0,  0),
            new Statistic('Jump',            2,  0,  0,  0,  0),
            new Statistic('AuditInitializer',1,  0,  0,  0,  0),
            new Statistic('Subsequence',     2,  0,  2,  0,  0),
            new Statistic('Subscribe',       2,  0,  9,  0,  0),
            new Statistic('Schedule',        1,  0,  0,  0,  0),
            new Statistic('AuditWriter',     0,  0,  0,  0,  0),
            new Statistic('Gate',            1,  0,  0,  0,  0),
            new Statistic('Scrape',          0,  0, 44,  0, 44),
            new Statistic('Mark',            0,  0,  0,  0,  0)
        };
    }
    
    @RemoteAction static public List<Statistic> getStatistics() {
        //initialize empty statistics for each process
        Map<String,Statistic> process2statistic = new Map<String,Statistic>();
        
        //#761 add null guy for all buffered messages
        process2statistic.put(' ', new Statistic(' ', 0, 0, 0, 0, 0));
        
        List<Process__c> processes = [
            SELECT Id, FullyQualifiedClassName__c
            FROM Process__c
            LIMIT 1000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        for (Process__c process : processes) {
            Statistic statistic = new Statistic(process.FullyQualifiedClassName__c, 0, 0, 0, 0, 0);
            process2statistic.put(process.FullyQualifiedClassName__c, statistic);
        }
        
        //check for null so we don't blow up for unresolved messages
        //TODO is there any point even displaying queued messages?!?!
        //first aggregate by route
        for (AggregateResult result : [
            SELECT FullyQualifiedClassName__c fqcn, COUNT(Status__c) total
            FROM Message__c
            WHERE Route__c != null
            AND Status__c = 'Queued'
            GROUP BY FullyQualifiedClassName__c
        ]) {
            process2statistic.get((String)result.get('fqcn')).Queued = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT FullyQualifiedClassName__c fqcn, COUNT(Status__c) total
            FROM Message__c
            WHERE Route__c != null
            AND Status__c = 'Buffered'
            GROUP BY FullyQualifiedClassName__c
        ]) {
            process2statistic.get(' ').Buffered = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT FullyQualifiedClassName__c fqcn, COUNT(Status__c) total
            FROM Message__c
            WHERE Route__c != null
            AND Status__c = 'Started'
            GROUP BY FullyQualifiedClassName__c
        ]) {
            process2statistic.get((String)result.get('fqcn')).Started = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT FullyQualifiedClassName__c fqcn, COUNT(Status__c) total
            FROM Message__c
            WHERE Route__c != null
            AND Status__c = 'Rebuffered'
            GROUP BY FullyQualifiedClassName__c
        ]) {
            process2statistic.get((String)result.get('fqcn')).Rebuffered = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT FullyQualifiedClassName__c fqcn, COUNT(Id) total
            FROM Message__c
            WHERE Route__c != null
            AND IsOverdue__c = true
            GROUP BY FullyQualifiedClassName__c
        ]) {
            process2statistic.get((String)result.get('fqcn')).Overdue = (Integer)result.get('total');
        }
        
        //pluck out the buffered guys (null per #697)
        Statistic none = process2statistic.remove(' ');
        List<String> classNames = new List<String>(process2statistic.keySet());
        classNames.sort();
        
        //sort buffered then alphabetical
        List<Statistic> statistics = new List<Statistic>{none};
        for (String className : classNames) statistics.add(process2statistic.get(className));
        return statistics;
    }
    
}