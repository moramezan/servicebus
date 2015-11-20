/**
 * Dan Appleman decoupler pattern
 * Don't upgrade API version!
 * Don't modify class body!
 * It'll never reinstall!
 */
global without sharing class Job implements Process.Plugin, System.Queueable {
    
    /**
     * We might prefer the system interface, but
     * but we can't do it for batch, so same here.
     */
    public interface Queueable {
        void run(Id messageId);
        void execute(QueueableContext context);
        void job(List<Map<String,Object>> inputEvents);
        Process.PluginDescribeResult describe();
        Process.PluginResult invoke(Process.PluginRequest request);
    }
    
    @TestVisible Queueable queue = (Queueable)Type.forName('Enqueue.Queue').newInstance();
    
    global Process.PluginDescribeResult describe() {
        return this.queue.describe();
    }
    
    global Process.PluginResult invoke(Process.PluginRequest request) {
        return this.queue.invoke(request);
    }
    
    public void execute(QueueableContext context) {
        this.queue.execute(context);
    }
    
    /**
     * We use this legitimately to "Wakeup" in rebuffer etc
     * But this constructor has to be public for Process.Plugin:
     * "System.TypeException: Job does not have a no-arg constructor"
     */
    global Job() {}
    
    global Job(String ToSequence, Id RecordId) {
        this(new Map<String,Object>{
            'ToSequence' => ToSequence,
            'RecordId' => RecordId
        });
    }
    
    global Job(Id ToConfig, Id RecordId) {
        //TODO Set<Id> ConfigIds
        this(new Map<String,Object>{
            'ToConfig' => ToConfig,
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
        this.queue.job(inputEvents);
    }
    
    /**
     * Was formerly Broker.run() but needs to be global now
     * for the sake of running from Execute Anonymous context.
     * The "runAsUser()" method needs to be able to call this.
     *
     * I think we had 8 global things in Job and 1 in Broker
     * Lets just have 9 global things in Job, and this proxies?
     *
     * We MUST ALWAYS prevent more than 1 running broker worker
     * otherwise they will fight over the work to be marked etc.
     */
    global void run(Id strategy) { //obfuscation of "messageId"
        this.queue.run(strategy);
    }
    
    /**
     * Wrapper class for enqueue parameters.
     */
    global class SimpleEvent {
        @InvocableVariable(required=false) global Id RecordId;
        @InvocableVariable(required=false) global String ToSequence;
        @InvocableVariable(required=false) global String ToService;
        @InvocableVariable(required=false) global String ToConfig; //TODO no Set<Id>
    }
    
    /**
     * Per #736 this enables developers to leverage Service Bus Jobs inside Process Builder
     * @docs ApiJobClass.html
     */
    @InvocableMethod(label='Enqueue Service Bus Job') global static List<Id> enqueue(List<SimpleEvent> simpleEvents) {
        List<Id> ids = new List<Id>();
        for (SimpleEvent simpleEvent : simpleEvents) {
            Map<String,Object> inputEvent = new Map<String,Object>{
                'ToSequence' => simpleEvent.ToSequence,
                'ToService' => simpleEvent.ToService,
                'ToConfig' => simpleEvent.ToConfig, //TODO no Set<Id>
                'RecordId' => simpleEvent.RecordId
            };
            Job job = new Job(inputEvent);
            Id jobId = System.enqueueJob(job);
            ids.add(jobId);
        }
        return ids;
    }
    
}