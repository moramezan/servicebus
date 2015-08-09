public with sharing class MonitorController {
    
    //eg "ns."
    public String getApexNamespacePrefix() {
        return MonitorController.class.getName().substringBefore('MonitorController');
    }
    
    public void doPing() {}
    
    public Boolean getIsBrokerRunning() {
        return Job.isScheduled() || Job.isRunning();
    }
    
    public Boolean getIsJobsWaiting() {
        System.Type type = Job.class;
        String namespacePrefix;
        String name;
        
        if (type.getName().contains('.')) {
            //managed (namespaceprefix.classname)
            namespacePrefix = type.getName().substringBefore('.');
            name = type.getName().substringAfter('.');
        } else {
            //unmanaged (classname)
            namespacePrefix = '';
            name = type.getName();
        }
        
        //find existing jobs
        Integer existingQueueableJobs = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :namespacePrefix AND ApexClass.Name = :name
            AND JobType IN ('Queueable')
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        
        return existingQueueableJobs != 0;
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
    
    @RemoteAction static public List<Statistic> getTestStatistics() {
        return new List<Statistic>{
            new Statistic(' ',               1, 32,  0,  0),
            new Statistic('Branch',          1,  0,  0,  0),
            new Statistic('GateByEntryPoint',         2,  0,  0,  0),
            new Statistic('GateByJob',         2,  0,  0,  0),
            new Statistic('Jump',         2,  0,  0,  0),
            new Statistic('Publish',         1,  0,  4,  0),
            new Statistic('Schedule',            2,  0,  0,  0),
            new Statistic('Subscribe',1,  0,  0,  0),
            new Statistic('Subsequence',     2,  0,  2,  0),
            new Statistic('Terminate',       2,  0,  9,  0),
            new Statistic('Wiretap',       2,  0,  9,  0)
        };
    }
    
    @RemoteAction static public List<Statistic> getStatistics() {
        //initialize empty statistics for each process
        Map<String,Statistic> step2statistic = new Map<String,Statistic>();
        
        //#761 add null guy for all buffered messages
        step2statistic.put(' ', new Statistic(' ', 0, 0, 0, 0));
        
        for (Step__c step : Step__c.getAll().values()) {
            Statistic statistic = new Statistic(step.Name, 0, 0, 0, 0);
            step2statistic.put(step.Name, statistic);
        }
        
        //check for null so we don't blow up for unresolved messages
        //TODO is there any point even displaying paused messages?!?!
        //first aggregate by route
        for (AggregateResult result : [
            SELECT Step__c step, COUNT(Status__c) total
            FROM Message__c
            WHERE Step__c != null
            AND Status__c = 'Paused'
            GROUP BY Step__c
        ]) {
            Statistic statistic = step2statistic.get((String)result.get('step')); //#761
            if (statistic == null) statistic = step2statistic.get(' ');
            statistic.Paused += (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Step__c step, COUNT(Status__c) total
            FROM Message__c
            WHERE Step__c != null
            AND Status__c = 'Buffered'
            GROUP BY Step__c
        ]) {
            step2statistic.get(' ').Buffered = (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Step__c step, COUNT(Status__c) total
            FROM Message__c
            WHERE Step__c != null
            AND Status__c = 'Started' AND Exception__c = null
            GROUP BY Step__c
        ]) {
            Statistic statistic = step2statistic.get((String)result.get('step')); //#761
            if (statistic == null) statistic = step2statistic.get(' ');
            statistic.Started += (Integer)result.get('total');
        }
        
        for (AggregateResult result : [
            SELECT Step__c step, COUNT(Status__c) total
            FROM Message__c
            WHERE Step__c != null
            AND Status__c = 'Started' AND Exception__c != null
            GROUP BY Step__c
        ]) {
            Statistic statistic = step2statistic.get((String)result.get('step')); //#761
            if (statistic == null) statistic = step2statistic.get(' ');
            statistic.Exceptions += (Integer)result.get('total');
        }
        
        //pluck out the buffered guys (null per #697)
        Statistic none = step2statistic.remove(' ');
        List<String> stepNames = new List<String>(step2statistic.keySet());
        stepNames.sort();
        
        //sort buffered then alphabetical
        List<Statistic> statistics = new List<Statistic>{none};
        for (String stepName : stepNames) statistics.add(step2statistic.get(stepName));
        return statistics;
    }
    
}