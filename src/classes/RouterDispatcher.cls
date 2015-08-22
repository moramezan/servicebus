public class RouterDispatcher implements System.Schedulable {

    public void execute(System.SchedulableContext context) {
        Type reflector = Type.forName('RouterImplementation');
        System.Schedulable job = (System.Schedulable)reflector.newInstance();
        job.execute(context);
    }
    
}