public without sharing class FutureBrokerDispatcher {
    
    public interface Restartable {
        void restart(String sessionId);
    }
    
    @future(callout=true) static public void restart(String sessionId) {
        Restartable future = (Restartable)Type.forName(FutureBrokerImplementation.class.getName()).newInstance();
        future.restart(sessionId);
    }
    
}