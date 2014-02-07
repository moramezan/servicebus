public class Processes extends SObjects {
    
    public Processes(List<Process__c> processes) {
        super(processes);
    }
    
    /**
     * This class is a template that must exist in every Process. It describes extra metadata around a process that
     * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
     * for an apex class to appear in the Process list.
     */
    private class Eda {
        /**
         * Each Process can have one associated customization in the form of a Custom Setting. Process Authors must
         * advertise the custom setting type here, and the framework will provide a link from the Process detail page.
         */
        public SObject customizable;
        
        /**
         * Each Chain Step can have one associated configuration record. The type of the record depends on what process
         * is living on the Chain Step. Process Authors must advertise the object type here, and the framework will 
         * handle the record lifecycle (creating and deleting them in tandem with the appropriate Chain Step).
         */
        public SObject configurable;
        
        /**
         * Each Process must name an icon (eg 'arrow_left') from the FamFamFam Silk library:
         * http://www.famfamfam.com/archive/silk-icons-thats-your-lot/
         */
        public String icon;
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
        Type innerClass = Type.forName(reflector.getName() + '.' + 'Eda');
        
        Process.Plugin plugin = (Process.Plugin)outerClass.newInstance();
        Process.PluginDescribeResult describeResult = plugin.describe();
        Eda meta;
        if (reflector.getName() != FailurePlugin.class.getName()) {
            meta = (Eda)Json.deserialize(Json.serialize(innerClass.newInstance()), Eda.class);
        }
        
        Process__c process = new Process__c(
            Name = describeResult.Name,
            Tag__c = describeResult.Tag,
            Description__c = describeResult.Description,
            FullyQualifiedClassName__c = outerClass.getName()
        );
        
        if (meta != null) {
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
        }
        
        return process;
    }
    
}