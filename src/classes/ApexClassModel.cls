/**
 * Domain layer for ApexClass (basically our processes)
 */
public class ApexClassModel extends ApexDomain.StandardModel {
    
    /**
     * For advertising domain layer errors
     */
    public class ProcessException extends Exception {}
    
    /**
     * The instance of our process definition
     */
    public ESB esb;
    
    /**
     * This class is a template that must exist in every Process. It describes extra metadata around a process that
     * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
     * for an apex class to appear in the Process list.
     *
     * @docs ApiMarkerClass.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        /**
         * Each process MAY provide a grouping tag.
         * @docs ApiProcessMarkers.html
         */
        public String Tag;
    
        /**
         * Each process MAY provide a friendly name.
         * @docs ApiProcessMarkers.html
         */
        public String Name;
    
        /**
         * Each process MUST provide a succinct description.
         * @docs ApiProcessMarkers.html
         */
        public String Description;
    
        /**
         * Each Process can have one associated customization in the form of a Custom Setting. Process Authors must
         * advertise the custom setting type here, and the framework will provide a link from the Process detail page.
         * @docs ApiProcessMarkers.html
         */
        public String ProcessSetting;
        
        /**
         * Each Step can have one associated config record. The type of the record depends on what process
         * is living on the Step. Process Authors must advertise the object type here, and the framework will
         * handle the record lifecycle (creating and deleting them in tandem with the appropriate Step).
         * @docs ApiProcessMarkers.html
         */
        public String StepConfig;
        
        /**
         * Each Process must name an icon (eg 'arrow_left') from the FamFamFam Silk library:
         * http://www.famfamfam.com/archive/silk-icons-thats-your-lot/
         * @docs ApiProcessMarkers.html
         */
        public String Icon;
        
        /**
         * Each Process can have one Visualforce Page for support and documentation purposes. Process Authors can
         * populate the property with a default value like Page.MyProcessDocs.getUrl() to make this available to users.
         * @docs ApiProcessMarkers.html
         */
        public String HelpUrl;
        
        /**
         * Each process defines the maximum number of times it can be invoked in a single execution context.
         * No definition implies a default limit of 1.
         * @docs ApiProcessMarkers.html
         */
        public Integer Limits;
    
        /**
         * Optional indicator of the ratio of output events to input events: -1 for fewer outputs (eg Gate),
         * 0 for no outputs (eg Terminate), 1 for a single output (eg Audit), null for any or many.
         * No definition implies a default cardinality of null.
         * @docs ApiProcessMarkers.html
         */
        public String Cardinality;
    
        /**
         * Key represents the parameter name, eg 'ns_URL'
         * Value is a friendly description, eg 'STRING of endpoint to scrape.'
         * @docs ApiProcessMarkers.html
         */
        public Map<String,String> Inputs;
        
        /**
         * Key represents the parameter name, eg 'ns_URL'
         * Value is a friendly description, eg 'STRING of endpoint to scrape.'
         * @docs ApiProcessMarkers.html
         */
        public Map<String,String> Outputs;
    }
    
    /**
     * This guy used in production
     */
    public ApexClassModel(ApexClass apexClass) {
        this(Type.forName(apexClass.NamespacePrefix, apexClass.Name));
        this.Record.Id = apexClass.Id;
    }
    
    static public ApexClassModel fromId(Id apexClassId) {
        ApexClass apexClass = (ApexClass)ApexDomain.getById(apexClassId);
        return new ApexClassModel(apexClass);
    }
    
    /**
     * Converts "their" ESB summary class into "our" ESB summary class
     */
    static public ApexClassModel.ESB esbFromEsb(Type reflector) {
        Type inflector;
        if (inflector == null) inflector = Type.forName(reflector.getName() + '.ESB');
        if (inflector == null) inflector = Type.forName(reflector.getName() + 'ESB');
        if (inflector == null) inflector = BaseSummary.class; //try and fail quietly
        
        Object theirEsb;
        ApexClassModel.ESB ourEsb;
        theirEsb = inflector.newInstance();
        ourEsb = (ApexClassModel.ESB)Json.deserialize(String.valueOf(theirEsb), ApexClassModel.ESB.class);
        
        //sensible defaults
        if (ourEsb.Description == null) ourEsb.Description = 'Undescribed';
        if (ourEsb.Tag == null) ourEsb.Tag = 'Untagged';
        if (ourEsb.Name == null) ourEsb.Name = reflector.getName();
        if (ourEsb.Icon == null) ourEsb.Icon = 'cog';
        if (ourEsb.Cardinality == null) ourEsb.Cardinality = 'Any';
        if (ourEsb.Limits == null || ourEsb.Limits < 1) ourEsb.Limits = 1;
        
        return ourEsb;
    }
    
    /**
     * Given a fully qualified class name, attempts to locate
     * the ESB inner marker class and parse all the properties.
     *
     * @throws ProcessException
     * @param apexClassName of the namespace prefix and apex class
     * @return domain model of process
     */
    public ApexClassModel(Type reflector) {
        super(new ApexClass(
            Name = reflector.getName()
        ));
        
        this.esb = esbFromEsb(reflector);
    }
    
    public String fullyQualifiedClassName() {
        ApexClass apexClass = (ApexClass)this.getRecord();
        return Type.forName(apexClass.Name).getName();
    }
    
    /**
     * Redirects the user to the ListView
     * URL of the specified Process Setting
     */
    public PageReference showSetting() {
        DescribeSObjectResult result = Schema.getGlobalDescribe().get(this.esb.ProcessSetting).getDescribe();
        
        if (result.isCustomSetting()) {
            //suffix only for custom settings
            return new PageReference('/' + result.getKeyPrefix() + '/o');
        } else {
            //console style only for custom objects
            return new PageReference('/' + result.getKeyPrefix() + '?isdtp=vw');
        }
    }
    
    /**
     * Base process to pretty up our own processes
     */
    abstract public class BaseProcess {
        
        /**
         * Internal only: we may override when process requires callouts
         */
        virtual void callouts(Map<String,Object> event) {}
        
        /**
         * Public implementation: they must put their logic inside
         */
        abstract List<Map<String,Object>> execute(Map<String,Object> inputEvent);
        
        /**
         * Public execution: they can use this for unit testing etc
         */
        public List<Map<String,Object>> test(Map<String,Object> inputEvent) {
            //#797 cycle inputs so process author sees consistent inputs
            inputEvent = (Map<String,Object>)Json.deserializeUntyped(Json.serialize(inputEvent));
            
            List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
            
            //#746 accumulate outputs so event parameters carry forwards
            for (Map<String,Object> result : this.execute(inputEvent)) {
                //output equals balance plus delta
                Map<String,Object> outputEvent = inputEvent.clone();
                outputEvent.putAll(result);
                outputEvents.add(outputEvent);
            }
            
            return outputEvents;
        }
        
        /**
         * Our only cross-namespace capability
         */
        override public String toString() {
            //arrange provider
            Process.Plugin provider = (Process.Plugin)Type.forName('Job').newInstance();
            Map<String,Object> request = new Map<String,Object>{'esb__EventProvider' => true};
            Map<String,Object> inputEvent = provider.invoke(new Process.PluginRequest(request)).OutputParameters;
            
            if (inputEvent.get('esb__AllowsCallouts') == true) {
                this.callouts(inputEvent);return null;
            } else {
                return Json.serialize(this.test(inputEvent));
            }
        }
        
    }
    
    /**
     * Base summary required for cross-namespace per #941
     */
    abstract public class BaseSummary {
        override public String toString() {
            return Json.serialize(this);
        }
    }
    
}