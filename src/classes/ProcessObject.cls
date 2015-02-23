public with sharing class ProcessObject extends SalesforceObject {
    
    public without sharing class ProcessException extends Exception {}
    
    public ProcessObject(Process__c process) {
        super(process);
    }
    
    /**
     * This class is a template that must exist in every Process. It describes extra metadata around a process that
     * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
     * for an apex class to appear in the Process list.
     * 
     * @docs ApiMarkerClass.html
     */
    public class ESB {
        /**
         * Each process MUST provide a grouping tag.
         * @docs ApiProcessMarkers.html
         */
        public String Tag {get;}

        /**
         * Each process MUST provide a friendly name.
         * @docs ApiProcessMarkers.html
         */
        public String Name {get;}

        /**
         * Each process MUST provide a succinct description.
         * @docs ApiProcessMarkers.html
         */
        public String Description {get;}

        /**
         * Each Process can have one associated customization in the form of a Custom Setting. Process Authors must
         * advertise the custom setting type here, and the framework will provide a link from the Process detail page.
         * @docs ApiProcessMarkers.html
         */
        public SObject ProcessSetting {get;}
        
        /**
         * Each Step can have one associated config record. The type of the record depends on what process
         * is living on the Step. Process Authors must advertise the object type here, and the framework will
         * handle the record lifecycle (creating and deleting them in tandem with the appropriate Step).
         * @docs ApiProcessMarkers.html
         */
        public SObject StepConfig {get;}
        
        /**
         * Each Process must name an icon (eg 'arrow_left') from the FamFamFam Silk library:
         * http://www.famfamfam.com/archive/silk-icons-thats-your-lot/
         * @docs ApiProcessMarkers.html
         */
        public String Icon {get;}
        
        /**
         * Each Process can have one Visualforce Page for support and documentation purposes. Process Authors can
         * populate the property with a default value like Page.MyProcessDocs.getUrl() to make this available to users.
         * @docs ApiProcessMarkers.html
         */
        public String HelpUrl {get;}
        
        /**
         * Each process defines the maximum number of times it can be invoked in a single execution context.
         * No definition implies a default limit of 1.
         * @docs ApiProcessMarkers.html
         */
        public Integer Limits {get;}

        /**
         * Key represents the parameter name, eg 'ns_URL'
         * Value is a friendly description, eg 'STRING of endpoint to scrape.'
         * @docs ApiProcessMarkers.html
         */
        public Map<String,String> Inputs {get;}
        
        /**
         * Key represents the parameter name, eg 'ns_URL'
         * Value is a friendly description, eg 'STRING of endpoint to scrape.'
         * @docs ApiProcessMarkers.html
         */
        public Map<String,String> Outputs {get;}
        
    }
    
    /**
     * Generates an inserted Process from a Type
     *
     * @param reflector Type of class whose process to generate
     * @return          Inserted process with all fields
     */
    @TestVisible static private Process__c generateOne(Type reflector) {
        if (!SObjectType.Process__c.Createable) throw new SalesforceObject.CrudException('!SObjectType.Process__c.Createable');
            
        Process__c process = fromType(reflector);
        insert process;
        return process;
    }
    
    public without sharing class Context {
        public Process__c contextFromType(Type reflector) {
            Type outerClass = reflector;
            Type innerClass = Type.forName(reflector.getName() + '.' + 'ESB');
            
            Object impl = outerClass.newInstance();
            Process__c process = new Process__c(
                FullyQualifiedClassName__c = outerClass.getName()
            );
            
            ProcessObject.ESB meta = (ProcessObject.ESB)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.ESB.class);

            if (meta.Description == null) {
                //EVERY PROCESS MUST PROVIDE A DESCRIPTION
                throw new ProcessException('Process "' + process.FullyQualifiedClassName__c + '" must provide ESB.Description');
            }

            //attempt to populate the short description of the process.
            process.Description__c = meta.Description.abbreviate(SObjectType.Process__c.Fields.Description__c.Length);

            //attempt to populate the tag of the process (with sensible default)
            process.Tag__c = meta.Tag == null ? 'Untagged' : meta.Tag.abbreviate(SObjectType.Process__c.Fields.Tag__c.Length);

            //attempt to populate the tag of the process (with sensible default)
            process.Name = meta.Name == null ? outerClass.getName() : meta.Name.abbreviate(SObjectType.Process__c.Fields.Name.Length);
            
            //attempt to populate the css class name of the process icon (with sensible default)
            process.Icon__c = meta.Icon == null ? 'cog' : meta.Icon.abbreviate(SObjectType.Process__c.Fields.Icon__c.Length);
            
            //attempt to populate the help url
            String helpUrl = meta.HelpUrl == null ? Page.ProcessDescribe.getUrl() + '?fqn=' + outerClass.getName() : meta.HelpUrl;
            if (helpUrl.startsWith('/')) helpUrl = Url.getSalesforceBaseUrl().toExternalForm() + helpUrl;
            process.HelpUrl__c = helpUrl.abbreviate(SObjectType.Process__c.Fields.HelpUrl__c.Length);

            if (meta.ProcessSetting != null) {
                //attempt to populate the name of the customization object
                process.Setting__c = meta.ProcessSetting.getSObjectType().getDescribe().getName();
            } else {
                process.Setting__c = null;
            }
            
            if (meta.StepConfig != null) {
                //attempt to populate the name of the config object
                process.StepConfig__c = meta.StepConfig.getSObjectType().getDescribe().getName();
            } else {
                process.StepConfig__c = null;
            }

            //attempt to populate the maximum executions
            process.Limits__c = (meta.Limits != null) ? meta.Limits : 1;    
            
            return process;
        }
    }
    
    /**
     * Generates an in-memory Process from a Type
     *
     * @param reflector Type of class whose process to generate
     * @return          In-memory process with all fields
     */
    static public Process__c fromType(Type reflector) {
        return new Context().contextFromType(reflector);
    }
    
}