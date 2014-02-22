public class AsyncApexJobs extends SObjects {
    
    /**
     * Domain constructor
     *
     * Note the only writeable property of an AsyncApexJob is Id.
     *
     * @param asyncApexJobs List of AsyncApexJob.
     */
    public AsyncApexJobs(List<AsyncApexJob> asyncApexJobs) {
        super(asyncApexJobs);
    }
    
    /**
     * Abort all batch jobs held in the domain instance.
     */
    public void abort() {
        for (AsyncApexJob asyncApexJob : (List<AsyncApexJob>)this.getSObjects()) {
            System.abortJob(asyncApexJob.Id);
        }
    }
    
    /**
     * Run a batch job only if not running already.
     *
     * @param  type      Reflector of the batchable class to run (eg Broker.class).
     * @param  chunkSize Chunk size for each iteration of the query locator (eg 200).
     * @return           Domain instance holding multiple existing jobs or one started job.
     */
    static public AsyncApexJobs runOne(System.Type type, Integer chunkSize) {
        String namespacePrefix;
        String name;
        
        if (type.getName().contains('.')) {
            //managed (namespaceprefix.classname)
            name = type.getName().substringBefore('.');
            namespacePrefix = type.getName().substringAfter('.');
        } else {
            //unmanaged (classname)
            name = type.getName();
            namespacePrefix = '';
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
            return new AsyncApexJobs(existingJobs);
        }
        
        //start job
        Id jobId = Database.executeBatch((Database.Batchable<Object>)type.newInstance(), chunkSize);
        
        //find started job
        List<AsyncApexJob> newJobs = [
            SELECT ApexClassId, JobType, Status, ExtendedStatus, JobItemsProcessed, TotalJobItems, LastProcessed
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        //return started job
        return new AsyncApexJobs(newJobs);
    }
}