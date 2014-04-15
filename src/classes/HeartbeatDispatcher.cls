/**
 * This class is WITHOUT SHARING to ensure the InstallHandler user context can access ApexClass etc
 * See http://salesforce.stackexchange.com/q/258/320 and http://salesforce.stackexchange.com/q/32607/320
 */
public without sharing class HeartbeatDispatcher implements System.Schedulable {

    public void execute(System.SchedulableContext context) {
        Type reflector = Type.forName(HeartbeatImplementation.class.getName());
        System.Schedulable job = (System.Schedulable)reflector.newInstance();
        job.execute(context);
    }
    
}