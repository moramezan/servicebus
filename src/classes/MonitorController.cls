public with sharing class MonitorController {
    
    public String getNamespacePrefix() {
        return MonitorController.class.getName().substringBefore('MonitorController');
    }
    
    public class Statistic {
        public Statistic(String name, Integer queued, Integer buffer, Integer processing, Integer reprocess, Integer overdue) {
            this.Name = name;
            this.Queued = queued;
            this.Buffer = buffer;
            this.Processing = processing;
            this.Reprocess = reprocess;
            this.Overdue = overdue;
        }
        
        public String Name {get; set;}
        public Integer Queued {get; set;}
        public Integer Buffer {get; set;}
        public Integer Processing {get; set;}
        public Integer Reprocess {get; set;}
        public Integer Overdue {get; set;}
    }
    
    @RemoteAction static public List<Statistic> getTestStatistics() {
        return new List<Statistic>{
            new Statistic('Branch',          1,  1,  0,  0,  0),
            new Statistic('Publish',         2, 14,  0,  0,  0),
            new Statistic('Wiretap',         1,  1,  4,  0,  0),
            new Statistic('Jump',            2,  1,  0,  0,  0),
            new Statistic('LogInitializer',  1,  1,  0,  0,  0),
            new Statistic('Subsequence',     2,  1,  2,  0,  0),
            new Statistic('Subscribe',       2, 14,  9,  0,  0),
            new Statistic('Schedule',        1,  1,  0,  0,  0),
            new Statistic('LogWriter',       0,  1,  0,  0,  0),
            new Statistic('Gate',            1,  1,  0,  0,  0),
            new Statistic('Scrape',          0,  0, 44,  0, 44),
            new Statistic('Mark',            0,  1,  0,  0,  0)
        };
    }
    
    @RemoteAction static public List<Statistic> getStatistics() {
        //we need to be able to populate the scattered statuses by process id
        Map<Id,Statistic> id2statistic = new Map<Id,Statistic>();
        
        //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        List<Process__c> processes = [
            SELECT Id, Name
            FROM Process__c
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        //populate id-keyed map for each process
        for (Process__c process : processes) {
            Statistic statistic = new Statistic(process.Name, 0, 0, 0, 0, 0);
            id2statistic.put(process.Id, statistic);
        }
        
        for (AggregateResult result : [SELECT Process__c processId, COUNT(Status__c) total FROM Message__c WHERE Status__c = 'Queued' GROUP BY Process__c]) {
            id2statistic.get((Id)result.get('processId')).Queued = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [SELECT Process__c processId, COUNT(Status__c) total FROM Message__c WHERE Status__c = 'Buffer' GROUP BY Process__c]) {
            id2statistic.get((Id)result.get('processId')).Buffer = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [SELECT Process__c processId, COUNT(Status__c) total FROM Message__c WHERE Status__c = 'Processing' GROUP BY Process__c]) {
            id2statistic.get((Id)result.get('processId')).Processing = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [SELECT Process__c processId, COUNT(Status__c) total FROM Message__c WHERE Status__c = 'Reprocess' GROUP BY Process__c]) {
            id2statistic.get((Id)result.get('processId')).Reprocess = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [SELECT Process__c processId, COUNT(Id) total FROM Message__c WHERE IsOverdue__c = true GROUP BY Process__c]) {
            id2statistic.get((Id)result.get('processId')).Overdue = (Integer)result.get('total');
        }
        
        return id2statistic.values();
    }
    
}