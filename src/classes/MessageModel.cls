/**
 * Domain layer for Message__c model
 */
public with sharing class MessageModel extends ApexDomain.StandardModel {
    
    public MessageModel(Message__c message) {
        super(message);
        this.Message = message;
    }
    
    static public MessageModel fromId(Id messageId) {
        Message__c message = (Message__c)ApexDomain.getById(messageId);
        return new MessageModel(message);
    }
    
    /**
     * For advertising domain layer errors
     */
    public class MessageException extends Exception {}
    
    /**
     * For cast-free convenience
     */
    private Message__c Message;
    
    /**
     * "Restarting" is the synchronous re-attempt of
     * a single message, with the hope of it reprocessing
     * successfully (presumably after changing something)
     *
     * In order to prevent inadvertent replay and keep
     * the message lifecycle correct, we do not allow casual
     * reprocessing of messages unless they Fucked or Killed.
     *
     * Fucked messages and Killed messages SHOULD both have
     * some non-null Exception. While that's not completely
     * guaranteed (we may see some time-out edge case etc)
     * its the most semantic signal we have at the moment.
     *
     * .------------- Messages with an Exception -------------.
     * |                                                      |
     * |   .-- Fucked messages --.   .-- Killed messages -.   |
     * |   |                     |   |                    |   |
     * |   | Status = Started    |   | Status = Completed |   |
     * |   | Exception != null   |   | Exception != null  |   |
     * |   |                     |   |                    |   |
     * |   '---------------------'   '--------------------'   |
     * |                                                      |
     * '------------------------------------------------------'
     *
     * I like to think of "Fucked" and "Killed" messages as both
     * being subsets of the common "Exception" messages.
     *
     * Analogous to how "execute" and "callouts" are both
     * sub-parts of the bigger concept of "invocation"
     *
     * @exception MessageException if you are not allowed to restart the message
     * @return true if synchronous reprocess succeeded, false if it failed
     */
    public Boolean restart() {
        
        if (this.Message.Exception__c == null) {
            //prevent inadvertent replay! yeah, we are not even looking at Status...
            throw new MessageException('Only messages with an Exception can be restarted.');
        }
        
        //do special run once broker
        Boolean result = Job.runOneAsUser(message.Id);
        
        if (!result) {
            //stop here and return
            return false;
        }
        
        //success, restart the REAL broker to carry on with the outputs
        Job.runAsUser();
        
        return true;
    }
    
}