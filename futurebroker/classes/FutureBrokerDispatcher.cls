/**
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class FutureBrokerDispatcher {
    
    public interface Restartable {
        void restart(String sessionId);
    }
    
    @future(callout=true) static public void restart(String sessionId) {
        Restartable future = (Restartable)Type.forName('FutureBrokerImplementation').newInstance();
        future.restart(sessionId);
    }
    
}