public with sharing class ProcessObject extends SalesforceObject {
    
    public without sharing class ProcessException extends Exception {}
    
    public ProcessObject(Process__c process) {
        super(process);
    }
    
    /**
     * This class is a template that must exist in every Process. It describes extra metadata around a process that
     * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
     * for an apex class to appear in the Process list.
     */
    public without sharing class Meta {
        /**
         * Each process MUST provide a grouping tag.
         */
        public String Tag {get;}

        /**
         * Each process MUST provide a friendly name.
         */
        public String Name {get;}

        /**
         * Each process MUST provide a succinct description.
         */
        public String Description {get;}

        /**
         * Each Process can have one associated customization in the form of a Custom Setting. Process Authors must
         * advertise the custom setting type here, and the framework will provide a link from the Process detail page.
         */
        public SObject CustomSetting {get;}
        
        /**
         * Each Step can have one associated config record. The type of the record depends on what process
         * is living on the Step. Process Authors must advertise the object type here, and the framework will
         * handle the record lifecycle (creating and deleting them in tandem with the appropriate Step).
         */
        public SObject StepConfig {get;}
        
        /**
         * Each Process must name an icon (eg 'arrow_left') from the FamFamFam Silk library:
         * http://www.famfamfam.com/archive/silk-icons-thats-your-lot/
         */
        public String Icon {get;}
        
        /**
         * Each Process can have one Visualforce Page for support and documentation purposes. Process Authors can
         * populate the property with a default value like Page.MyProcessDocs.getUrl() to make this available to users.
         */
        public String HelpUrl {get;}
        
        /**
         * Input Parameters
         */
        public Map<String,String> Inputs {get;}
        
        /**
         * Output Parameters
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
        if (!SObjectType.Process__c.Createable) throw new Broker.CrudException('!SObjectType.Process__c.Createable');
            
        Process__c process = fromType(reflector);
        insert process;
        return process;
    }
    
    public without sharing class Context {
        public Process__c contextFromType(Type reflector) {
            Type outerClass = reflector;
            Type innerClass = Type.forName(reflector.getName() + '.' + 'Meta');
            
            Object impl = outerClass.newInstance();
            Process__c process = new Process__c(
                FullyQualifiedClassName__c = outerClass.getName()
            );
            
            ProcessObject.Meta meta = (ProcessObject.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.Meta.class);

            if (meta.Description == null) {
                //EVERY PROCESS MUST PROVIDE A DESCRIPTION
                throw new ProcessException('Process "' + process.FullyQualifiedClassName__c + '" must provide Meta.Description');
            }

            //attempt to populate the short description of the process.
            process.Description__c = meta.Description;

            //attempt to populate the tag of the process (with sensible default)
            process.Tag__c = meta.Tag == null ? 'Untagged' : meta.Tag;

            //attempt to populate the tag of the process (with sensible default)
            process.Name = meta.Name == null ? outerClass.getName() : meta.Name;
            
            //attempt to populate the css class name of the process icon (with sensible default)
            process.Icon__c = meta.Icon == null ? 'cog' : meta.Icon;
            
            //attempt to populate the help url
            process.HelpUrl__c = meta.HelpUrl == null ? Page.ProcessDescribe.getUrl() + '?fqn=' + outerClass.getName() : meta.HelpUrl;
            if (process.HelpUrl__c.startsWith('/')) process.HelpUrl__c = Url.getSalesforceBaseUrl().toExternalForm() + process.HelpUrl__c;

            if (meta.CustomSetting != null) {
                //attempt to populate the name of the customization object
                process.CustomSetting__c = meta.CustomSetting.getSObjectType().getDescribe().getName();
            }
            
            if (meta.StepConfig != null) {
                //attempt to populate the name of the config object
                process.StepConfig__c = meta.StepConfig.getSObjectType().getDescribe().getName();
            }

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