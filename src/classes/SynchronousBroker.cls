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
            
            try {
            
                //EXECUTE
                List<Message__c> outputMessages = new List<Message__c>();
                this.execute(inputMessages, outputMessages);
                
                //PERSIST
                List<Message__c> inputAndOutputMessages = new List<Message__c>();
                inputAndOutputMessages.addAll(inputMessages);
                inputAndOutputMessages.addAll(outputMessages);
                this.persist(inputAndOutputMessages); //#782
                
            } catch (Exception e) {
            
                for (Message__c inputMessage : inputMessages) {
                    inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                    inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                }
                
                //write away error text on messages
                update inputMessages;
                
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