/**
 * Domain layer for ApexClass (basically our processes)
 */
public class ApexClassModel extends ApexDomain.StandardModel {
    
    /**
     * For advertising domain layer errors
     */
    public class ApexClassException extends Exception {}
    
    /**
     * This class is a template that must exist in every Process. It describes extra metadata around a process that
     * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
     * for an apex class to appear in the Process list.
     *
     * @docs ApiMarkerClass.html
     */
    public class Summary extends ApexClassModel.BaseSummary {
        public String Tag {get; set;}
        public String Name {get; set;}
        public String Description {get; set;}
        public String ProcessSetting {get; set;}
        public String StepConfig {get; set;}
        public String Icon {get; set;}
        public String HelpUrl {get; set;}
        public Integer Limits {get; set;}
        public String Cardinality {get; set;}
        public Map<String,String> Inputs {get; set;}
        public Map<String,String> Outputs {get; set;}
        
        /**
         * Attempts to parse all ESB summary class properties.
         */
        public Summary(Type reflector) {
            Type inflector;
            if (inflector == null) inflector = Type.forName(reflector + '.ESB');
            if (inflector == null) inflector = Type.forName(reflector + 'ESB');
            if (inflector == null) {
                //failure, bad inner class
                throw new ApexClassException('ESB Process summary class is invalid or not visible: ' + reflector.getName());
            }
            
            Map<String,Object> summary;
            try {
                //their summary class
                Object impl = inflector.newInstance();
                String toString = String.valueOf(impl);
                summary = (Map<String,Object>)Json.deserializeUntyped(toString);
                
            } catch (Exception e) {
                //failure, probably bad toString method
                throw new ApexClassException(inflector.getName() + ': ESB Process summary class must extend Abstract.ESB.Summary');
            }
            
            try {
                //copy properties across
                this.Tag = (String)summary.get('Tag');
                this.Name = (String)summary.get('Name');
                this.Description = (String)summary.get('Description');
                this.ProcessSetting = (String)summary.get('ProcessSetting');
                this.StepConfig = (String)summary.get('StepConfig');
                this.Icon = (String)summary.get('Icon');
                this.HelpUrl = (String)summary.get('HelpUrl');
                this.Limits = (Integer)summary.get('Limits');
                this.Cardinality = (String)summary.get('Cardinality');
                this.Inputs = (Map<String,String>)Json.deserialize(Json.serialize(summary.get('Inputs')), Map<String,String>.class);
                this.Outputs = (Map<String,String>)Json.deserialize(Json.serialize(summary.get('Outputs')), Map<String,String>.class);
                
                //set sensible defaults
                if (this.Tag == null) this.Tag = 'Untagged';
                if (this.Name == null) this.Name = reflector.getName(); //inflector.getName().replaceAll('\\.?ESB$', ''); //strips .ESB
                if (this.Description == null) this.Description = 'Undescribed';
                if (this.Icon == null) this.Icon = 'cog';
                if (this.Limits == null) this.Limits = 1;
                if (this.Cardinality == null) this.Cardinality = 'Any';
                
                //#955 cap Limits ceiling
                if (this.Limits > 2000) this.Limits = 2000;
                if (this.Limits < 1) this.Limits = 1; //be sensible

            } catch (Exception e) {
                //failure, probably bad json format
                throw new ApexClassException(inflector.getName() + ': Could not resolve value binding: ' + e.getMessage());
            }
        }
    }
    
    static public ApexClassModel fromId(Id apexClassId) {
        ApexClass apexClass = (ApexClass)ApexDomain.getById(apexClassId);
        return new ApexClassModel(apexClass);
    }
    
    /**
     * This guy used in production
     */
    public ApexClassModel(ApexClass apexClass) {
        this(Type.forName(apexClass.NamespacePrefix, apexClass.Name));
        this.Record = apexClass;
    }
    
    /**
     * This guy more handy in testing
     */
    public ApexClassModel(Type reflector) {
        super(new ApexClass(Name = reflector.getName()));
        this.Reflector = reflector;
    }
    
    /**
     * Redirects the user to the ListView
     * URL of the specified Process Setting
     */
    public PageReference showSetting() {
        Summary summary = new Summary(this.Reflector);
        DescribeSObjectResult result = Schema.getGlobalDescribe().get(summary.ProcessSetting).getDescribe();
        
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
        virtual protected void callout(Map<String,Object> inputEvent) {}
        
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
            
            List<Map<String,Object>> outputEvents = this.execute(inputEvent);
            
            //#746 accumulate outputs so event parameters carry forwards
            if (outputEvents != null) for (Integer i = 0; i < outputEvents.size(); i++) {
                //"aggregate" equals our "input balance" plus their "output delta"
                Map<String,Object> aggregate = inputEvent.clone();
                aggregate.putAll(outputEvents[i]);
                outputEvents[i] = aggregate;
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
                this.callout(inputEvent);return null;
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
    
    /**
     * Used in callout and execute
     */
    public Type Reflector;
    
    /**
     * User process instance (transient prevents inadvertent toString() / serialization)
     */
    transient Object Process;
    
    /**
     * TODO COUNT ANY DMLS
     */
    public void invokeCallout(Map<String,Object> inputEvent) {
        
        if (inputEvent == null) {
            //our own fault
            throw new ApexClassException('ApexClassModel.invokeCallout must receive an input event.');
        }
        
        if (this.Process == null) {
            //doing this later than earlier
            this.Process = this.Reflector.newInstance();
        }
        
        //provide input event and set flag
        Job.Event = inputEvent.clone();
        Job.Event.put('esb__AllowsCallouts', true);
        
        //do invocation
        String data = String.valueOf(this.Process);
        
        if (data != null) {
            //#886 a la "MyCustomException: Exception class must extend another Exception class"
            throw new ApexClassException(this.Reflector.getName() + ': ESB Process must extend Abstract.ESB');
        }
    }
    
    /**
     * TODO COUNT ANY CALLOUTS
     */
    public List<Map<String,Object>> invokeExecute(Map<String,Object> inputEvent) {
        
        if (inputEvent == null) {
            //our own fault
            throw new ApexClassException('ApexClassModel.invokeExecute must receive an input event.');
        }
        
        if (this.Process == null) {
            //doing this later than earlier
            this.Process = this.Reflector.newInstance();
        }
        
        //provide input event and set flag
        Job.Event = inputEvent.clone();
        Job.Event.put('esb__AllowsCallouts', false);
        
        //#877 surface SessionId to select few orgs and packages
        //Boolean allowSessionId = Broker.isAllowedSessionId(step.ApexClassName__c, UserInfo.getOrganizationId());
        //if (allowSessionId) Job.Event.put('__SessionId', OAuthSetting__c.getOrgDefaults().AccessToken__c);
        //TODO for #886
        
        //do invocation
        String data = String.valueOf(this.Process);
        
        if (data == null || data == 'null') {
            //#945 a la "System.VisualforceException: Return type of an Apex action method must be a PageReference. Found: java.lang.Integer"
            throw new ApexClassException(this.Reflector.getName() + ': Return type of an ESB Process must be a List<Map<String,Object>>');
        }
        
        if (data.startsWith(('.' + this.Reflector.getName()).substringAfterLast('.') + ':[')) {
            //#886 a la "MyCustomException: Exception class must extend another Exception class"
            throw new ApexClassException(this.Reflector.getName() + ': ESB Process must extend Abstract.ESB');
        }
        
        //wrap up results into events (new guys should have Position = 0)
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        
        if (inputEvent.get('esb__Process') != null) {
            //#956 "fire and forget" means don't persist outputs
            return outputEvents;
        }
        
        List<Object> results = (List<Object>)Json.deserializeUntyped(data);
        
        if (results.size() > 5000) {
            //#955 blow up too many output events emitted
            throw new ApexClassException(this.Reflector.getName() + ': Too many output events: ' + results.size());
        }
        
        for (Object result : results) {
            Map<String,Object> outputEvent = (Map<String,Object>)result;
            
            /**
             * Context:
             * A message can pass through a limited number of steps. This "limit" is a fairly high arbitrary threshold.
             * The intent is to prevent a never ending self referencing loop (we cannot control what the system configurators
             * configure). A self referencing loop would eventually ring alarm bells with the Salesforce police with the
             * possibility of the Munger being blacklisted
             * An exception is thrown if the Max Hops threshold is reached
             *
             * We cannot simply increment __Hops BEFORE calling invoke as a process writer could fuck with this parameter
             * Instead we read and increment __Hops BEFORE calling invoke using enforceMaximumHops()
             * and assign to an Integer hops variable
             * We use applyHops()  to apply the incremented hops variable to the __Hops parameter of
             * all messages returned from invoke()
             */
            Integer hops = (Integer)outputEvent.get('__Hops');
            if (hops == null) hops = 0;
            outputEvent.put('__Hops', ++hops);
            
            outputEvents.add(outputEvent);
        }
        
        return outputEvents;
    }
    
}