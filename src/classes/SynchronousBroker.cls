public with sharing class SynchronousBroker extends Broker {

    static private Boolean isRunning = false;
    
    override public void restartImpl() {
        SynchronousBroker.isRunning = true;
        this.start();
    }
    
    virtual public void start() {
        //start (MARK)
        Database.QueryLocator locator = this.locateMarkedWork(1);
        Database.QueryLocatorIterator iterator = locator.iterator();
        
        //execute (EXECUTE, RESOLVE, PERSIST)
        while (iterator.hasNext()) {
            //each in separate execution context
            Message__c message = (Message__c)iterator.next();
            this.executeResolvePersist(message.Id); //EXECUTE
        }
        
        //finish (invokes broker again in same context)
        this.restartIfWorkPending();
    }
    
    override public Boolean isAlreadyRunning() {
        return SynchronousBroker.isRunning;
    }
    
}