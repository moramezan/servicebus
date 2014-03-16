public class Processes extends SObjects {
    
    public Processes(List<Process__c> processes) {
        super(processes);
    }
    
    /**
     * This class is a template that must exist in every Process. It describes extra metadata around a process that
     * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
     * for an apex class to appear in the Process list.
     */
    @testVisible
    private class Meta {
        /**
         * Each Process can have one associated customization in the form of a Custom Setting. Process Authors must
         * advertise the custom setting type here, and the framework will provide a link from the Process detail page.
         */
        public SObject customizable;
        
        /**
         * Each Step can have one associated configuration record. The type of the record depends on what process
         * is living on the Step. Process Authors must advertise the object type here, and the framework will
         * handle the record lifecycle (creating and deleting them in tandem with the appropriate Step).
         */
        public SObject configurable;
        
        /**
         * Each Process must name an icon (eg 'arrow_left') from the FamFamFam Silk library:
         * http://www.famfamfam.com/archive/silk-icons-thats-your-lot/
         */
        public String icon;
        
        /**
         * Each Process can have one Visualforce Page for support and documentation purposes. Process Authors can
         * populate the property with a default value like Page.MyProcessHelp.getUrl() to make this available to users.
         */
        public String helpPageUrl;
    }
    
    /**
     * Generates an inserted Process from a Type
     *
     * @param reflector Type of class whose process to generate
     * @return          Inserted process with all fields
     */
    @testVisible static private Process__c generateOne(Type reflector) {
        Process__c process = fromType(reflector);
        insert process;
        return process;
    }
    
    /**
     * Generates an in-memory Process from a Type
     *
     * @param reflector Type of class whose process to generate
     * @return          In-memory process with all fields
     */
    static public Process__c fromType(Type reflector) {
        Type outerClass = reflector;
        Type innerClass = Type.forName(reflector.getName() + '.' + 'Meta');
        
        Process.Plugin plugin = (Process.Plugin)outerClass.newInstance();
        Process.PluginDescribeResult describeResult = plugin.describe();
        Process__c process = new Process__c(
            Name = describeResult.Name,
            Tag__c = describeResult.Tag,
            Description__c = describeResult.Description,
            FullyQualifiedClassName__c = outerClass.getName()
        );
        
        //special exception for BrokerTest.FailurePlugin as used in testing
        if (reflector.getName() == BrokerTest.FailurePlugin.class.getName()) return process;
        
        Processes.Meta meta = (Processes.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), Processes.Meta.class);
        
        if (meta.customizable != null) {
            //attempt to populate the name of the customization object
            process.Customizable__c = meta.customizable.getSObjectType().getDescribe().getName();
        }
        
        if (meta.configurable != null) {
            //attempt to populate the name of the configuration object
            process.Configurable__c = meta.configurable.getSObjectType().getDescribe().getName();
        }
        
        if (meta.icon != null) {
            //attempt to populate the css class name of the process icon
            process.Icon__c = meta.icon;
        }
        
        //attempt to populate the visualforce help page url (maybe at some point we can check it for validity)
        //note: if a help page is removed and the key taken out of the Meta class, we allow null to be written
        process.HelpPageUrl__c = meta.helpPageUrl;
        
        return process;
    }
    
}