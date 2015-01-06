public with sharing class SynchronousBroker extends Broker {

    static private Boolean isRunning = false;
    
    override public void restartImpl() {
        SynchronousBroker.isRunning = true;
        this.start();
    }
    
    public void start() {
        //LOCATE
        List<Message__c> messages = this.locateMarkableWork();
        
        //MARK
        this.mark(messages);
        
        for (Message__c message : messages) {
            List<Message__c> inputMessages = new List<Message__c>{message};
            
            List<Message__c> outputMessages;
            try {
            
                //EXECUTE
                outputMessages = this.execute(inputMessages);
                
                //PERSIST
                this.persist(inputMessages, outputMessages);
                
            } catch (EngineException e) {
            
                //revert, except callouts which should really be idempotent anyway
                if (e.savepoint != null) Database.rollback(e.savepoint);
                
                //write away error text on messages
                update e.fuckups;
                
                //stop, don't resolve
                //finish (invokes broker again in same context)
                this.restartIfWorkPending();
                return;
                
            }
        }
        
        //finish (invokes broker again in same context)
        this.restartIfWorkPending();
    }
    
    override public Boolean isAlreadyRunning() {
        return SynchronousBroker.isRunning;
    }
    
}