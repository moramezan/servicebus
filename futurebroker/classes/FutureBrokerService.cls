global class FutureBrokerService {
    
    static webservice void doStart() {
        //replaces tooling api
        Page.FutureBroker.getContent();
    }
    
    static webservice void doHandle(Id messageId) {
        //replaces tooling api
        PageReference pr = Page.FutureBroker;
        pr.getParameters().put('id', messageId);
        pr.getContent(); //EXECUTE
    }
    
    static webservice void doMark(List<Id> messageIds) {
        //replaces tooling api
        Broker.mark(new Set<Id>(messageIds));
    }
    
}