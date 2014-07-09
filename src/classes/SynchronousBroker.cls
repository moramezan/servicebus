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
            
            SavePoint sp = Database.setSavePoint();
            try {
                //EXECUTE
                List<Message__c> outputMessages = this.execute(inputMessages);
                
                //RESOLVE
                this.resolve(outputMessages);
                
                //PERSIST
                this.persist(inputMessages, outputMessages);
            } catch (Exception e) {
                //no emails or database activity thanks!
                Database.rollback(sp);
                
                Message__c inputMessage = inputMessages[0];
                this.surfaceException(e, inputMessage.Id);
            }
        }
        
        //finish (invokes broker again in same context)
        this.restartIfWorkPending();
    }
    
    override public Boolean isAlreadyRunning() {
        return SynchronousBroker.isRunning;
    }
    
}