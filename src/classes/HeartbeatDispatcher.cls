public class HeartbeatDispatcher implements System.Schedulable {

    public void execute(System.SchedulableContext context) {
        Type reflector = Type.forName('HeartbeatImplementation');
        System.Schedulable job = (System.Schedulable)reflector.newInstance();
        job.execute(context);
    }
    
}