/**
 * Dan Appleman decoupler pattern
 * Don't upgrade API version!
 * Don't modify class body!
 * It'll never reinstall!
 */
public without sharing class RouterSchedule implements System.Schedulable { //@obfuscation HeartbeatDispatcher
    
    /**
     * We might prefer the system interface, but
     * but we can't do it for batch, so same here.
     */
    public interface Schedulable {
        void execute(System.SchedulableContext context);
    }
    
    @TestVisible Schedulable schedule = (Schedulable)Type.forName('Router.ScheduleImpl').newInstance();
    
    public void execute(System.SchedulableContext context) {
        this.schedule.execute(context);
    }
    
}