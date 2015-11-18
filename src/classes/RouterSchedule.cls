/**
 * @Obfuscation
 * Formerly known as HeartbeatDispatcher
 */
public class RouterSchedule implements System.Schedulable {

    public void execute(System.SchedulableContext context) {
        Type reflector = Type.forName('Router.Schedule');
        System.Schedulable job = (System.Schedulable)reflector.newInstance();
        job.execute(context);
    }
    
}