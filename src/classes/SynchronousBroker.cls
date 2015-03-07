public with sharing class SynchronousBroker extends Broker {

    static private Boolean isRunning = false;
    
    override public void runImpl() {
        //aligns ok with batch mental model
        this.start();
        this.execute();
        this.finish();
    }
    
    public void start() {
        SynchronousBroker.isRunning = true;
    }
    
    public void execute() {
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
                List<Message__c> inputAndOutputMessages = new List<Message__c>();
                inputAndOutputMessages.addAll(inputMessages);
                inputAndOutputMessages.addAll(outputMessages);
                this.persist(inputAndOutputMessages); //#782
                
            } catch (EngineException e) {
            
                //revert, except callouts which should really be idempotent anyway
                if (e.savepoint != null) Database.rollback(e.savepoint);
                
                //write away error text on messages
                update e.fuckups;
                
                //stop, don't resolve
                //finish (invokes broker again in same context)
                Broker.run();
                return;
                
            }
        }
    }
    
    public void finish() {
        //indicate stop because run ONLY runs if stopped
        SynchronousBroker.isRunning = false;
        
        //finish (invokes broker again in same context)
        Broker.run();
    }
    
    override public Boolean isRunning() {
        return SynchronousBroker.isRunning;
    }
    
}