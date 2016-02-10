/**
 * Domain layer for ApexClass (basically our services)
 */
public class ApexClassModel extends ApexDomain.StandardModel {
    
    public class ModelException extends Exception {}
    
    /**
     * This class is a template that must exist in every Service. It describes extra metadata around a service that
     * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
     * for an apex class to appear in the Services list.
     *
     * @docs ApiMarkerClass.html
     */
    virtual public class Definition {
        public Definition() {}
        override public String toString() {return Json.serialize(this);}
        public Id Id {get; set;} //#946
        public String Tag {get; set;}
        public String Label {get; set;}
        public String Description {get; set;}
        public String ServiceConfig {get; set;}
        public String StepConfig {get; set;}
        public String Icon {get; set;}
        public String HelpUrl {get; set;}
        public Boolean Retry {get; set;}
        public Integer Chunks {get; set;}
        public String Cardinality {get; set;}
        public Map<String,String> Inputs {get; set;}
        public Map<String,String> Outputs {get; set;}
        
        /**
         * Attempts to parse all Service.Definition class properties.
         */
        public Definition(Type reflector) {
            Type inflector;
            if (inflector == null) inflector = Type.forName(reflector + '.Definition');
            if (inflector == null) inflector = Type.forName(reflector + 'Definition'); //makes testing easier
            if (inflector == null) {
                //failure, bad inner class
                throw new ModelException('Service.Definition class is invalid or not visible: ' + reflector.getName());
            }
            
            //all definition classes have toString()
            String toString;
            Object impl = inflector.newInstance();
            Map<String,Object> definition;
            
            try {
                //TODO remove this
                toString = Json.serialize(impl);
            } catch (Exception e) {
                //failure, unmanaged non extending
                toString = String.valueOf(impl);
            }
            
            try {
                //checks format
                definition = (Map<String,Object>)Json.deserializeUntyped(toString);
            } catch (Exception e) {
                //failure, probably bad toString method
                throw new ModelException(inflector.getName() + ': Service.Definition class must extend Abstract.Service.Definition');
            }
            
            try {
                //copy properties across
                this.Tag = (String)definition.get('Tag');
                this.Label = (String)definition.get('Label');
                this.Description = (String)definition.get('Description');
                this.ServiceConfig = (String)definition.get('ServiceConfig');
                this.StepConfig = (String)definition.get('StepConfig');
                this.Icon = (String)definition.get('Icon');
                this.HelpUrl = (String)definition.get('HelpUrl');
                this.Retry = (Boolean)definition.get('Retry');
                this.Chunks = (Integer)definition.get('Chunks');
                this.Cardinality = (String)definition.get('Cardinality');
                this.Inputs = (Map<String,String>)Json.deserialize(Json.serialize(definition.get('Inputs')), Map<String,String>.class);
                this.Outputs = (Map<String,String>)Json.deserialize(Json.serialize(definition.get('Outputs')), Map<String,String>.class);
                
                //set sensible defaults
                if (this.Tag == null) this.Tag = 'Untagged';
                if (this.Label == null) this.Label = reflector.getName(); //inflector.getName().replaceAll('\\.?Definition$', ''); //strips any '.Definition' or 'Definition'
                if (this.Description == null) this.Description = 'Undescribed';
                if (this.Icon == null) this.Icon = 'cog';
                if (this.Chunks == null) this.Chunks = 1;
                if (this.Cardinality == null) this.Cardinality = 'Any';
                if (this.Retry == null) this.Retry = false;
                
                //#955 cap Chunks ceiling
                if (this.Chunks > 200) this.Chunks = 200; //#1038 even more breathing room //#955 possibly 2000, but headspace
                if (this.Chunks < 1) this.Chunks = 1; //be sensible

            } catch (Exception e) {
                //failure, probably bad json format
                throw new ModelException(inflector.getName() + ': Could not resolve value binding: ' + e.getMessage());
            }
        }
    }
    
    static public ApexClassModel fromId(Id apexClassId) {
        ApexClass apexClass = (ApexClass)ApexDomain.getById(apexClassId);
        return new ApexClassModel(apexClass);
    }
    
    /**
     * This performs actual resolution inside the callout and/or execute method.
     */
    static public ApexClassModel fromRoute(String route) {
        
        if (route == null) {
            //failure, a la "List has no rows for assignment to SObject"
            throw new ModelException('Route was null.');
        }
        
        //resolve class name
        String apexTypeName = route;
        Step__c step = Step__c.getValues(route);
        if (step != null) apexTypeName = step.ApexTypeName__c;
        
        if (route.contains('#') && step == null) {
            //failure, a la "Could not resolve field 'Billing Address' from value binding"
            throw new ModelException('Could not resolve route: ' + route);
        }
        
        if (apexTypeName == null) {
            //failure, a la "Argument cannot be null"
            throw new Broker.ServiceException('Apex class name cannot be null: ' + route);
        }
        
        Type reflector;
        
        try {reflector = Type.forName(apexTypeName);} catch (Exception e) {
            //failure, a la "Could not resolve field 'Billing Address' from value binding"
            throw new ModelException('Could not reflect ' + apexTypeName + ': ' + e.getMessage());
        }
        
        if (reflector == null) {
            //a la "Variable is not visible" or "Variable does not exist" or "Dependent class is invalid and needs recompilation"
            throw new ModelException('Class is invalid or not visible: ' + apexTypeName);
        }
        
        //also works with #956 "fire and forget" service without sequences or steps
        ApexClassModel model = new ApexClassModel(reflector);
        if (step != null) model.getRecord().Id = step.ApexClassId__c;
        return model;
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
     * Injects a test message to this service
     * carrying just the Organization Id.
     *
     * @return the queueable job id
     */
    public Id enqueueTestMessage() {
        //Enqueue.AllowRoute = true; //#999#issuecomment-133751700
        Map<String,Object> event = new Map<String,Object>{
            'ToService' => this.Reflector.getName()
        };
        Id jobId = Enqueue.invoke(event);
        return jobId;
    }
    
    /**
     * Used to determine the list/tab redirect
     * when showing the ApexClassConfig page
     */
    public DescribeSObjectResult describeServiceConfig() {
        Definition definition = new Definition(this.Reflector);
        DescribeSObjectResult result = Schema.getGlobalDescribe().get(definition.ServiceConfig).getDescribe();
        return result;
    }
    
    /**
     * Redirects user to the HelpURL
     * specified on the Service Definition
     */
    public PageReference showHelpUrl() {
        Definition definition = new Definition(this.Reflector);
        if (definition.HelpUrl == null) return null;
        return new PageReference(definition.HelpUrl);
    }
    
//THERE IS A BINDING BETWEEN: abstract/classes/Service.cls and src/classes/ApexClassModel.cls
/**
 * MUST BE GLOBAL IN ABSTRACT PACKAGE
 */
//abstract global class Service {
abstract public class Service {
    
    /**
     * MUST BE PRESENT IN ABSTRACT PACKAGE
     */
    //abstract global class Definition {override public String toString() {return Json.serialize(this);}}
    
    /**
     * MUST BE VIRTUAL GLOBAL IN ABSTRACT PACKAGE
     */
    //virtual global void callout(Map<String,Object> inputEvent) {}
    abstract private void callout(Map<String,Object> inputEvent);
    
    /**
     * MUST BE VIRTUAL GLOBAL IN ABSTRACT PACKAGE
     */
    //virtual global List<Map<String,Object>> execute(Map<String,Object> inputEvent) {return new List<Map<String,Object>>{inputEvent};}
    abstract private List<Map<String,Object>> execute(Map<String,Object> inputEvent);
    
    /**
     * MUST BE GLOBAL IN ABSTRACT PACKAGE
     */
    //global List<Map<String,Object>> handle(Map<String,Object> inputEvent) {
    public List<Map<String,Object>> handle(Map<String,Object> inputEvent) {
        
        //invoke callout
        this.EventProvider = Json.serialize(inputEvent);
        this.AllowsCallouts = true;
        String.valueOf(this);
        
        //invoke execute
        this.EventProvider = Json.serialize(inputEvent);
        this.AllowsCallouts = false;
        String data = String.valueOf(this);
        
        //respect null return
        if (data == null) return null;
        
        //prepare real outputs
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        
        //cast each one
        for (Object result : (List<Object>)Json.deserializeUntyped(data)) outputEvents.add((Map<String,Object>)result);
        
        //eg works with [ {}, null, {} ]
        return outputEvents;
    }
    
    /**
     * Our only cross-namespace capability
     */
    override public String toString() {
        //#797 cycle json so service author sees consistent inputs
        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(this.EventProvider);
        
        if (this.AllowsCallouts == true) {
            
            //invoke callout
            this.AllowsCallouts = false;
            this.callout(inputEvent);
            return null;
            
        } else if (this.AllowsCallouts == false) {
            
            //invoke execute
            List<Map<String,Object>> outputEvents = this.execute(inputEvent);
            
            //#746 accumulate outputs so event parameters carry forwards
            if (outputEvents != null) for (Integer i = 0; i < outputEvents.size(); i++) {
                if (outputEvents[i] == null) continue;
                
                //"aggregate" equals our "input balance" plus their "output delta"
                Map<String,Object> aggregate = inputEvent.clone();
                aggregate.putAll(outputEvents[i]);
                outputEvents[i] = aggregate;
            }
            
            //retain camouflage after
            this.AllowsCallouts = null;
            
            //#797 cycle json so service author sees consistent outputs
            return Json.serialize(outputEvents);
            
        } else { //this.AllowsCallouts == null
            
            //camouflage... lol
            return 'Service:[]';
            
        }
    }
    
    String EventProvider = '{}';
    Boolean AllowsCallouts;
}
    
    /**
     * Used in callout and execute
     */
    public Type Reflector;
    
    /**
     * User service instance (transient prevents inadvertent toString() / serialization)
     *
     * NB we see the side effects code in two places. Both the
     * MessageModel and the ApexClassModel. It's for different
     * reasons.
     *
     * This checks side effects to prevent DML in callout etc.
     * The MessageModel needs to know side effects for the "savepoint tax".
     */
    transient Object Service;
    
    /**
     * #1147 merges the Enqueue-Helper / Persist-Increment
     * into a common routing method used throughout package.
     *
     * A few examples:
     * - Route:1#Handler#3 becomes 1#Handler#4
     * - ToService:Wiretap becomes Route:Wiretap
     * - ToSequence:Handle becomes Route:V#Handle#1
     * - ToConfigIds:[new] becomes Route:V#Sequence#1
     * - ToConfigIds:[old] becomes Route:TerminateService
     */
    static public void route(Map<String,Object> event) {
        String route = (String)event.get('Route');
        
        //stamp with version
        Integer version = Application__c.getOrgDefaults().RouterVersion__c.intValue();
        if (route != null && route.contains('#')) version = Integer.valueOf(route.substringBefore('#'));
        
        //increments route position (arrives 1#MySeq#3 leaves 1#MySeq#4)
        if (route != null && route.contains('#')) {
            Integer position = Integer.valueOf(route.substringAfterLast('#')) + 1;
            String sequence = route.substringAfter('#').substringBefore('#');
            event.put('Route', version + '#' + sequence + '#' + position);
        }
        
        //#999 routing helpers (controls route without knowledge of routing)
        Set<Id> toConfigIds = (Set<Id>)Json.deserialize(Json.serialize(event.get('ToConfigIds')), Set<Id>.class);
        String toSequence = (String)event.get('ToSequence');
        String toService = (String)event.get('ToService');
        
        //converts sequence to route
        if (toSequence != null) {
            Integer position = 1;
            event.remove('ToSequence');
            event.put('services:ToSequence', toSequence);
            event.put('Route', version + '#' + toSequence + '#' + position);
        }
        
        //converts service to route
        if (toService != null) {
            event.remove('ToService');
            event.put('services:ToService', toService);
            event.put('Route', toService);
        }
        
        //converts config to route
        if (toConfigIds != null) {
            Integer position = 1;
            event.remove('ToConfigIds');
            event.put('services:ToConfigIds', toConfigIds);
            
            for (Step__c step : Step__c.getAll().values()) {
                if (step.Version__c == version && toConfigIds.contains(step.ConfigId__c)) {
                    //correct version with correct config
                    event.put('Route', version + '#' + step.Sequence__c + '#' + position);
                    break;
                } else {
                    //old step or absent config
                    event.put('Route', TerminateService.class.getName());
                    continue;
                }
            }
        }
    }
    
    public void invokeCallout(Map<String,Object> inputEvent) {
        
        if (inputEvent == null) {
            //our own fault
            throw new ModelException('ApexClassModel.invokeCallout must receive an input event.');
        }
        
        if (this.Service == null) {
            //provide input event and set flag
            Map<String,Object> proxy = new Map<String,Object>{'EventProvider' => Json.serialize(inputEvent), 'AllowsCallouts' => true};
            this.Service = Json.deserialize(Json.serialize(proxy), this.Reflector);
        }
        
        //do invocation
        String data;
        try {
            //measure side effects before
            Integer futureCalls = Limits.getFutureCalls();
            Integer queueableJobs = Limits.getQueueableJobs();
            Integer dmlStatements = Limits.getDMLStatements();
            Integer emailInvocations = Limits.getEmailInvocations();
            
            data = String.valueOf(this.Service);
            
            //measure side effects after
            if (Limits.getFutureCalls() > futureCalls) throw new Broker.ServiceException('You have uncommitted work pending. Please commit or rollback before calling out');
            if (Limits.getQueueableJobs() > queueableJobs) throw new Broker.ServiceException('You have uncommitted work pending. Please commit or rollback before calling out');
            if (Limits.getDMLStatements() > dmlStatements) throw new Broker.ServiceException('You have uncommitted work pending. Please commit or rollback before calling out');
            if (Limits.getEmailInvocations() > emailInvocations) throw new Broker.ServiceException('You have uncommitted work pending. Please commit or rollback before calling out');
            
        } catch (Exception e) {
            if (TransactionService.IsRunning) {
                //#995 help transaction bail out
                String message = this.Reflector.getName() + ': Callout from transaction not supported. Consider using jumps instead.';
                if (!Test.isRunningTest()) System.assert(false, message);
                else throw new Broker.ServiceException(message);
            }
            
            if (e.getMessage() == 'You have uncommitted work pending. Please commit or rollback before calling out') {
                //#981 put work in proper method please... fucking uncommit using system rollback (no savepoint because callout!)
                String message = this.Reflector.getName() + ': Side effects from callout() not supported. Please do that in the execute() method.';
                if (!Test.isRunningTest()) System.assert(false, message);
                else throw new Broker.ServiceException(message);
            }
            
            //https://github.com/bigassforce/services/commit/529cffff570ef99dccb8f5589a0767a498f2c019#commitcomment-12843056
            throw e;
        }
        
        if (data != null) {
            //#886 a la "MyCustomException: Exception class must extend another Exception class"
            throw new Broker.ServiceException(this.Reflector.getName() + ': Service must extend Abstract.Service');
        }
    }
    
    public List<Map<String,Object>> invokeExecute(Map<String,Object> inputEvent) {
        
        if (inputEvent == null) {
            //our own fault
            throw new ModelException('ApexClassModel.invokeExecute must receive an input event.');
        }
        
        if (this.Service == null) {
            //provide input event and set flag
            Map<String,Object> proxy = new Map<String,Object>{'EventProvider' => Json.serialize(inputEvent), 'AllowsCallouts' => false};
            this.Service = Json.deserialize(Json.serialize(proxy), this.Reflector);
        }
        
        //#877 surface SessionId to select few orgs and packages
        //Boolean allowSessionId = Broker.isAllowedSessionId(step.ApexTypeName__c, UserInfo.getOrganizationId());
        //if (allowSessionId) Job.Event.put('SessionId', Application__c.getOrgDefaults().RunAsAccessToken__c);
        //TODO for #886
        
        //do invocation
        String data;
        try {
            data = String.valueOf(this.Service);
        } catch (System.CalloutException e) {
            if (e.getMessage() == 'You have uncommitted work pending. Please commit or rollback before calling out') {
                //#981 put callout in proper method please
                throw new Broker.ServiceException(this.Reflector.getName() + ': Callout from execute() not supported. Please do that in the callout() method.');
            }
            
            //https://github.com/bigassforce/services/commit/529cffff570ef99dccb8f5589a0767a498f2c019#commitcomment-12843061
            throw e;
        }
        
        if (data == null || data == 'null') {
            //#945 a la "System.VisualforceException: Return type of an Apex action method must be a PageReference. Found: java.lang.Integer"
            throw new Broker.ServiceException(this.Reflector.getName() + ': Return type of a Service execute method must be a List<Map<String,Object>>');
        }
        
        if (data.startsWith(('.' + this.Reflector.getName()).substringAfterLast('.') + ':[')) {
            //#886 a la "MyCustomException: Exception class must extend another Exception class"
            throw new Broker.ServiceException(this.Reflector.getName() + ': Service must extend Abstract.Service');
        }
        
        //wrap up results into events (new guys should have Position = 0)
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        
        List<Object> results = (List<Object>)Json.deserializeUntyped(data);
        
        if (results.size() > 1000) { //#955 possibly 5000, but headspace
            //#955 blow up too many output events emitted
            throw new Broker.ServiceException(this.Reflector.getName() + ': Too many output events: ' + results.size());
        }
        
        for (Object result : results) {
            if (result == null) {
                //#976 catch "surprise" null events
                throw new Broker.ServiceException(this.Reflector.getName() + ': Output event cannot be null'); //a la System.NullPointerException: Argument cannot be null
            }
            
            if (!(result instanceof Map<String,Object>)) {
                //catch non map-string objects (unlikely unless custom nuclear tip)
                throw new Broker.ServiceException(this.Reflector.getName() + ': Output event must be a Map<String,Object>'); //a la Return type of an Apex action method must be a PageReference. Found: java.lang.Integer
            }
            
            Map<String,Object> outputEvent = (Map<String,Object>)result;
            
            
            String route = (String)outputEvent.get('Route');
            if (route != null && !route.contains('#') && inputEvent.get('Route') == outputEvent.get('Route')) {
                //#956 "fire and forget" means don't persist outputs, unless they were explicitly destined to sequence or service
                continue; //TODO needs more testing
            }
            
            /**
             * Context:
             * A message can pass through a limited number of steps. This "limit" is a fairly high arbitrary threshold.
             * The intent is to prevent a never ending self referencing loop (we cannot control what the system configurators
             * configure). A self referencing loop would eventually ring alarm bells with the Salesforce police with the
             * possibility of the Munger being blacklisted
             * An exception is thrown if the Max Hops threshold is reached
             *
             * We cannot simply increment Hops BEFORE calling invoke as a service author could fuck with this parameter
             * Instead we read and increment Hops BEFORE calling invoke using enforceMaximumHops()
             * and assign to an Integer hops variable
             * We use applyHops()  to apply the incremented hops variable to the Hops parameter of
             * all messages returned from invoke()
             */
            Integer hops = (Integer)outputEvent.get('Hops');
            if (hops == null) hops = 0;
            outputEvent.put('Hops', ++hops);
            
            outputEvents.add(outputEvent);
        }
        
        return outputEvents;
    }
    
    
    
}