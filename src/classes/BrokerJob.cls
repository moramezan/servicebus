/**
 * Dan Appleman decoupler pattern
 * Don't upgrade API version!
 * Don't modify class body!
 * It'll never reinstall!
 */
public without sharing class BrokerJob implements System.Queueable, Database.AllowsCallouts {
    
    /**
     * We might prefer the system interface, but
     * but we can't do it for batch, so same here.
     */
    public interface Queueable {
        void execute(QueueableContext context);
    }
    
    public void execute(QueueableContext context) {
        Queueable queue = (Queueable)Type.forName('Enqueue.QueueImpl').newInstance();
        queue.execute(context);
    }
    
}