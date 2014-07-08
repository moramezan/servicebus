public with sharing class SynchronousBroker extends Broker {

    static private Boolean isRunning = false;
    
    override public void restartImpl() {
        SynchronousBroker.isRunning = true;
        this.start();
    }
    
    virtual public void start() {
        //LOCATE
        Database.QueryLocator locator = this.locateMarkableWork(1);
        Database.QueryLocatorIterator iterator = locator.iterator();
        
        //MARK
        this.mark(new ApexPages.StandardSetController(locator).getRecords());
        
        while (iterator.hasNext()) {
            Message__c message = (Message__c)iterator.next();
            
            List<Message__c> inputMessages = new List<Message__c>{message};
            
            //EXECUTE
            List<Message__c> outputMessages = this.execute(inputMessages); //EXECUTE
            
            //RESOLVE
            this.resolve(outputMessages);
            
            //PERSIST
            this.persist(inputMessages, outputMessages);
        }
        
        //finish (invokes broker again in same context)
        this.restartIfWorkPending();
    }
    
    override public Boolean isAlreadyRunning() {
        return SynchronousBroker.isRunning;
    }
    
}