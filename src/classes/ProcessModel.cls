/**
 * This class is a template that must exist in every Process. It describes extra metadata around a process that
 * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
 * for an apex class to appear in the Process list.
 *
 * @docs ApiMarkerClass.html
 */
public with sharing class ProcessModel {
    
    /**
     * Used as the key/id when manipulating ESB processes.
     * This is a phantom property populated automatically.
     */
    public String FullyQualifiedClassName {get; set;}
    
    /**
     * Each process MUST provide a grouping tag.
     * @docs ApiProcessMarkers.html
     */
    public String Tag {get; set;}

    /**
     * Each process MUST provide a friendly name.
     * @docs ApiProcessMarkers.html
     */
    public String Name {get; set;}

    /**
     * Each process MUST provide a succinct description.
     * @docs ApiProcessMarkers.html
     */
    public String Description {get; set;}

    /**
     * Each Process can have one associated customization in the form of a Custom Setting. Process Authors must
     * advertise the custom setting type here, and the framework will provide a link from the Process detail page.
     * @docs ApiProcessMarkers.html
     */
    public String ProcessSetting {get; set;}
    
    /**
     * Each Step can have one associated config record. The type of the record depends on what process
     * is living on the Step. Process Authors must advertise the object type here, and the framework will
     * handle the record lifecycle (creating and deleting them in tandem with the appropriate Step).
     * @docs ApiProcessMarkers.html
     */
    public String StepConfig {get; set;}
    
    /**
     * Each Process must name an icon (eg 'arrow_left') from the FamFamFam Silk library:
     * http://www.famfamfam.com/archive/silk-icons-thats-your-lot/
     * @docs ApiProcessMarkers.html
     */
    public String Icon {get; set;}
    
    /**
     * Each Process can have one Visualforce Page for support and documentation purposes. Process Authors can
     * populate the property with a default value like Page.MyProcessDocs.getUrl() to make this available to users.
     * @docs ApiProcessMarkers.html
     */
    public String HelpUrl {get; set;}
    
    /**
     * Each process defines the maximum number of times it can be invoked in a single execution context.
     * No definition implies a default limit of 1.
     * @docs ApiProcessMarkers.html
     */
    public Integer Limits {get; set;}

    /**
     * Optional indicator of the ratio of output events to input events: -1 for fewer outputs (eg Gate),
     * 0 for no outputs (eg Terminate), 1 for a single output (eg Audit), null for any or many.
     * No definition implies a default cardinality of null.
     * @docs ApiProcessMarkers.html
     */
    public String Cardinality {get; set;}

    /**
     * Key represents the parameter name, eg 'ns_URL'
     * Value is a friendly description, eg 'STRING of endpoint to scrape.'
     * @docs ApiProcessMarkers.html
     */
    public Map<String,String> Inputs {get; set;}
    
    /**
     * Key represents the parameter name, eg 'ns_URL'
     * Value is a friendly description, eg 'STRING of endpoint to scrape.'
     * @docs ApiProcessMarkers.html
     */
    public Map<String,String> Outputs {get;}
    
    /**
     * For advertising domain layer errors
     */
    public without sharing class ProcessException extends Exception {}
    
    /**
     * Privatize constructor to force use of fromFqcn()
     */
    private ProcessModel() {}
    
    /**
     * Given a fully qualified class name, attempts to locate
     * the ESB inner marker class and parse all the properties.
     *
     * @throws ProcessException
     * @param fullyQualifiedClassName of the namespace prefix and apex class
     * @return domain model of process
     */
    static public ProcessModel fromFqcn(String fullyQualifiedClassName) {
        Type innerClass = Type.forName(fullyQualifiedClassName + '.' + 'ESB');
        if (innerClass == null) innerClass = Type.forName(fullyQualifiedClassName + 'ESB');
        
        ProcessModel model;
        try {
            model = (ProcessModel)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessModel.class);
        } catch (JsonException e) {
            throw new ProcessException('Process discovery exception "' + fullyQualifiedClassName + '"', e);
        }
        
        //populate our key for internal use
        model.FullyQualifiedClassName = fullyQualifiedClassName;
        
        //attempt to populate the description of the process
        if (model.Description == null) model.Description = 'Undescribed';

        //attempt to populate the tag of the process (with sensible default)
        if (model.Tag == null) model.Tag = 'Untagged';

        //attempt to populate the name of the process (with sensible default)
        if (model.Name == null) model.Name = fullyQualifiedClassName;
        
        //attempt to populate the css class name of the process icon (with sensible default)
        if (model.Icon == null) model.Icon = 'cog';
        
        //attempt to populate the cardinality of the process
        if (model.Cardinality == null) model.Cardinality = 'Any';
        
        //attempt to populate the maximum executions
        if (model.Limits == null) model.Limits = 1;
        
        //attempt to populate the help url
        if (model.HelpUrl == null) model.HelpUrl = Page.ProcessDescribe.getUrl() + '?fqcn=' + fullyQualifiedClassName;
        if (model.HelpUrl.startsWith('/')) model.HelpUrl = Url.getSalesforceBaseUrl().toExternalForm() + model.HelpUrl;
        
        //attempt to populate the name of the customization object
        
        //attempt to populate the name of the config object
        
        return model;
    }
    
    /**
     * Locates all ESB processes by attempting to interrogate ESB marker inner class;
     * for each apex class found with a marker, it will try to parse the properties.
     */
    static public List<ProcessModel> discoverProcesses() {
        //select out all apex classes
        List<ApexClass> apexClasses = [
            SELECT Id, Name, NamespacePrefix
            FROM ApexClass
            ORDER BY Name ASC
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        //reflect on each ESB marker inner class
        List<String> fullyQualifiedClassNames = new List<String>();
        for (ApexClass apexClass : apexClasses) {
            Type reflector;
            try {
                reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            } catch (TypeException e ) {
                //some compile problem with the class, eg LeadShare when OWD set to public
                continue;
            }
            
            if (reflector == null) continue; //eg private classes
            String fullyQualifiedClassName = reflector.getName();
            
            Type meta = Type.forName(fullyQualifiedClassName + '.' + 'ESB');
            if (meta == null) meta = Type.forName(fullyQualifiedClassName + 'ESB');
            if (meta != null) fullyQualifiedClassNames.add(fullyQualifiedClassName);
        }
        
        //assemble a list of process models where valid
        List<ProcessModel> processes = new List<ProcessModel>();
        for (String fullyQualifiedClassName : fullyQualifiedClassNames) {
            try {
                processes.add(ProcessModel.fromFqcn(fullyQualifiedClassName));
            } catch (ProcessException e) {
                continue;
            }
        }
        
        return processes;
    }
    
    /**
     * Base process to pretty up our processes
     */
    abstract public with sharing class BaseProcess {
        
        //only override when a process requires callouts
        @TestVisible virtual protected void callouts(Map<String,Object> event) {}
        
        //always override and implement process logic inside
        @TestVisible abstract protected List<Map<String,Object>> execute(Map<String,Object> event);
        
        //ESB Marker Method
        override public String toString() {
            Process.PluginRequest eventProviderRequest = new Process.PluginRequest(new Map<String,Object>{'esb__EventProvider' => true});
            Map<String,Object> inputEvent = new Job().invoke(eventProviderRequest).OutputParameters;
            Boolean allowsCallouts = (Boolean)inputEvent.get('esb__AllowsCallouts');
            if (allowsCallouts == true) {this.callouts(inputEvent);return null;}
            return Json.serialize(this.execute(inputEvent));
        }
        
    }
    
}