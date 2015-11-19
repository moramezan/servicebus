/**
 * @Obfuscation
 * Formerly known as HeartbeatDispatcher
 */
public class RouterSchedule implements System.Schedulable {
    
    /**
     * We might prefer the system interface, but
     * but we can't do it for batch, so same here.
     */
    public interface Schedulable {
        void execute(System.SchedulableContext context);
    }
    
    Schedulable schedule = (Schedulable)Type.forName('Router.Schedule').newInstance();
    
    public void execute(System.SchedulableContext context) {
        this.schedule.execute(context);
    }
    
}