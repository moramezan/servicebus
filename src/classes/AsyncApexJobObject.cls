public with sharing class AsyncApexJobObject extends SalesforceObject {
    
    /**
     * Domain constructor
     *
     * Note the only writeable property of an AsyncApexJob is Id.
     *
     * @param asyncApexJob The AsyncApexJob.
     */
    public AsyncApexJobObject(AsyncApexJob asyncApexJob) {
        super(asyncApexJob);
    }
    
    /**
     * Abort all batch jobs held in the domain instance.
     */
    public void abort() {
        System.abortJob(this.getSObject().Id);
    }
    
    /**
     * Run a batch job only if not running already.
     *
     * @param  type      Reflector of the batchable class to run (eg Broker.class).
     * @param  chunkSize Chunk size for each iteration of the query locator (eg 200).
     * @return           Domain instance holding multiple existing jobs or one started job.
     */
    static public AsyncApexJobObject runOne(System.Type type, Integer chunkSize) {
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
        List<AsyncApexJob> existingJobs = [
            SELECT ApexClassId, JobType, Status, ExtendedStatus, JobItemsProcessed, TotalJobItems, LastProcessed
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :namespacePrefix AND ApexClass.Name = :name
            AND JobType IN ('BatchApex', 'ScheduledApex')
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        
        if (!existingJobs.isEmpty()) {
            //return existing job
            return new AsyncApexJobObject(existingJobs[0]);
        }
        
        //start job
        Id jobId = Database.executeBatch((Database.Batchable<Object>)type.newInstance(), chunkSize);
        
        //find started job
        AsyncApexJob job = (AsyncApexJob)SalesforceObject.getById(jobId);
        
        //return started job
        return new AsyncApexJobObject(job);
    }
}