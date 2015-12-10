/**
 * Dan Appleman decoupler pattern
 * Don't upgrade API version!
 * Don't modify class body!
 * It'll never reinstall!
 */
global without sharing class Job implements System.Queueable, Database.AllowsCallouts {
    
    //void run(Id messageId);
    //void job(List<Map<String,Object>> inputEvents);
    
    /**
     * We might prefer the system interface, but
     * but we can't do it for batch, so same here.
     */
    public interface Queueable {
        void setEvents(List<Map<String,Object>> inputEvents);
        void execute(QueueableContext context);
    }
    
    @TestVisible Queueable queue = (Queueable)Type.forName('Enqueue.Queue').newInstance();
    
    global void execute(QueueableContext context) {
        this.queue.execute(context);
    }
    
    /**
     * We use this legitimately to "Wakeup" in rebuffer etc
     */
    global Job() {}
    
    global Job(String ToSequence, Id RecordId) {
        this(new Map<String,Object>{
            'ToSequence' => ToSequence,
            'RecordId' => RecordId
        });
    }
    
    global Job(Type ToService, Id RecordId) {
        this(new Map<String,Object>{
            'ToService' => ToService.getName(),
            'RecordId' => RecordId
        });
    }
    
    global Job(Map<String,Object> inputEvent) {
        this(new List<Map<String,Object>>{inputEvent});
    }
    
    global Job(List<Map<String,Object>> inputEvents) {
        this.queue.setEvents(inputEvents);
    }
    
}