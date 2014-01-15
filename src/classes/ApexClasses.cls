public class ApexClasses extends SObjects {

    /**
     * This class is a template that must exist in every Process. It describes extra metadata around a process that
     * isn't appropriate for Tag, Description, InputParameters or OutputParameters. This inner class must be present
     * for an apex class to appear in the Process list.
     */
    public class Eda {
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
    }
    
    public ApexClasses(List<ApexClass> apexClasses) {
        super(apexClasses);
    }
    
    public List<Process__c> regenerate() {
        Set<Id> ids = new Map<Id,SObject>(this.getSObjects()).keySet();
        List<ApexClass> apexClasses = [SELECT Id, NamespacePrefix, Name FROM ApexClass WHERE Id IN :ids];
        List<Process__c> processes = new List<Process__c>();
        
        for (ApexClass apexClass : apexClasses) {
            Type outerClass = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            Type innerClass = Type.forName(apexClass.NamespacePrefix, apexClass.Name + '.' + 'Eda');
            try {
                if (innerClass != null && outerClass.newInstance() instanceof Process.Plugin) {
                    Process.Plugin plugin = (Process.Plugin)outerClass.newInstance();
                    Process.PluginDescribeResult describeResult = plugin.describe();
                    Eda meta = (Eda)Json.deserialize(Json.serialize(innerClass.newInstance()), Eda.class);
                    
                    Process__c process = new Process__c(
                        Name = outerClass.getName(),
                        Tag__c = describeResult.Tag,
                        Description__c = describeResult.Description
                    );
                    
                    if (meta.customizable != null) {
                        //attempt to populate the name of the customization object
                        process.Customizable__c = meta.customizable.getSObjectType().getDescribe().getName();
                    }
                    
                    if (meta.configurable != null) {
                        //attempt to populate the name of the configuration object
                        process.Configurable__c = meta.configurable.getSObjectType().getDescribe().getName();
                    }
                    
                    processes.add(process);
                }
            } catch (Exception e) {}
        }
        return processes;
    }
}