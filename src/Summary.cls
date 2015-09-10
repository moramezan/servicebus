/**
 * This is an inner class template within every microservice. It describes special metadata around
 * a service, such as its event parameters and cardinality. Some of these properties such as the
 * icon and the config object can be used to present a user interface for configuring the service.
 */
public class Summary extends Abstract.Service.Summary {
    
    /**
     * Optional indicator of the ratio of
     * output events to input events. Eg:
     * 'Zero' (service swallows events)
     * 'One' (one input and one output)
     * 'Many' (service splits events)
     * 'Fewer' (service aggregates events)
     */
    String Cardinality;
    
    /**
     * Optional number of times this service can run in one execution context, while remaining
     * within governor limits. For example, 50 for a service that issues an HTTP callout.
     */
    Integer Limits;
    
    /**
     * Optional URL to help for this service.
     * This will be displayed alongside instances.
     */
    String HelpUrl;
    
    /**
     * Optional fully-qualified API name of a Custom Object to be used for instance-specific
     * service configuration. One record is displayed on each instance, and injected into the event.
     */
    String StepConfig;
    
    /**
     * Optional fully-qualified API name of a Custom Setting to be used for service-specific
     * configuration. Records of this type are manageable wherever the service is displayed.
     */
    String ServiceSetting;
    
    /**
     * Optional friendly descriptions of the input
     * event parameters required by this service.
     */
    Map<String,String> Inputs;
    
    /**
     * Optional friendly descriptions of the output event parameters emitted by this service. Not
     * to be confused with events themselves, of which a service may emit zero, one, or many.
     */
    Map<String,String> Outputs;
    
    /**
     * Optional icon name from the Silk Library that
     * will display alongside instances of this service.
     */
    String Icon;
    
    /**
     * Required descriptioon that explains what
     * this service does in simple terms.
     */
    String Description;
    
    /**
     * Optional friendly name to be displayed instead
     * of the fully-qualified Apex Class name.
     */
    String Name;
    
    /**
     * Optional grouping tag that can be used to
     * categorize related services together.
     */
    String Tag;
    
}
