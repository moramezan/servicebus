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
    @TestVisible private without sharing class Meta {
        /**
         * Each process MUST provide a grouping tag.
         */
        public String Tag;

        /**
         * Each process MUST provide a friendly name.
         */
        public String Name;

        /**
         * Each process MUST provide a succinct description.
         */
        public String Description;

        /**
         * Each Process can have one associated customization in the form of a Custom Setting. Process Authors must
         * advertise the custom setting type here, and the framework will provide a link from the Process detail page.
         */
        public SObject CustomSetting;
        
        /**
         * Each Step can have one associated configuration record. The type of the record depends on what process
         * is living on the Step. Process Authors must advertise the object type here, and the framework will
         * handle the record lifecycle (creating and deleting them in tandem with the appropriate Step).
         */
        public SObject ConfigObject;
        
        /**
         * Each Process must name an icon (eg 'arrow_left') from the FamFamFam Silk library:
         * http://www.famfamfam.com/archive/silk-icons-thats-your-lot/
         */
        public String Icon;
        
        /**
         * Each Process can have one Visualforce Page for support and documentation purposes. Process Authors can
         * populate the property with a default value like Page.MyProcessDocs.getUrl() to make this available to users.
         */
        public String DocsPageUrl;
        
        //Inputs
        //Outputs
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
            
            //special exception for BrokerTest.FailureProcess as used in testing
            if (reflector.getName() == BrokerTest.class.getName()) return process;
            
            ProcessObject.Meta meta = (ProcessObject.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.Meta.class);

            if (meta.Tag == null) {
                //EVERY PROCESS MUST PROVIDE A TAG
                throw new ProcessException('Process "' + process.FullyQualifiedClassName__c + '" must provide Meta.Tag');
            }

            //attempt to populate the tag of the process
            process.Tag__c = meta.Tag;


            if (meta.Name == null) {
                //EVERY PROCESS MUST PROVIDE A NAME
                throw new ProcessException('Process "' + process.FullyQualifiedClassName__c + '" must provide Meta.Name');
            }

            //attempt to populate the tag of the process
            process.Name = meta.Name;


            if (meta.Description == null) {
                //EVERY PROCESS MUST PROVIDE A DESCRIPTION
                throw new ProcessException('Process "' + process.FullyQualifiedClassName__c + '" must provide Meta.Description');
            }

            //attempt to populate the tag of the process
            process.Description__c = meta.Description;

            if (meta.CustomSetting != null) {
                //attempt to populate the name of the customization object
                process.CustomSetting__c = meta.CustomSetting.getSObjectType().getDescribe().getName();
            }
            
            if (meta.ConfigObject != null) {
                //attempt to populate the name of the configuration object
                process.ConfigObject__c = meta.ConfigObject.getSObjectType().getDescribe().getName();
            }
            
            if (meta.Icon != null) {
                //attempt to populate the css class name of the process icon
                process.Icon__c = meta.Icon;
            } else {
               process.Icon__c = 'cog'; 
            }
            
            if (meta.DocsPageUrl != null) {
                //populate the help page url
                process.DocsPageUrl__c = meta.DocsPageUrl;
            } else {
                //EVERY PROCESS MUST PROVIDE A HELP PAGE
                throw new ProcessException('Process "' + process.FullyQualifiedClassName__c + '" must provide Meta.DocsPageUrl');
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