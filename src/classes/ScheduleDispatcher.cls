/**
 * Skinny with no need to upgrade.
 */
public without sharing class ScheduleDispatcher implements System.Schedulable {

    public void execute(System.SchedulableContext context) {
        Type reflector = Type.forName(ScheduleImplementation.class.getName());
        System.Schedulable job = (System.Schedulable)reflector.newInstance();
        job.execute(context);
    }
    
}