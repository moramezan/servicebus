public class ApexClasses extends SObjects {

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
    
    public ApexClasses(List<ApexClass> apexClasses) {
        super(apexClasses);
    }
    
    /**
     * Factory to return domain layer from a list of System.Type instances
     *
     * @param types List of System.Type, from eg Type.forName() or Impl.class
     * @return      Domain instance holding Apex Class objects for all the types.
     */
    static public ApexClasses fromTypes(List<System.Type> types) {
        List<String> clauses = new List<String>();
        for (System.Type type : types) {
            String clause;
            if (type.getName().contains('.')) {
                //managed (namespaceprefix.classname)
                clause = '(NamespacePrefix = \'' + type.getName().substringAfter('.') + '\' AND Name = \'' + type.getName().substringAfter('.') + '\')';
            } else {
                //unmanaged (classname)
                clause = '(Name = \'' + type.getName() + '\')';
            }
            clauses.add(clause);
        }
        String query = 'SELECT Id FROM ApexClass WHERE ' + String.join(clauses, 'OR');
        List<ApexClass> apexClasses = Database.query(query);
        return new ApexClasses(apexClasses);
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
                        Name = describeResult.Name,
                        Tag__c = describeResult.Tag,
                        Description__c = describeResult.Description,
                        FullyQualifiedClassName__c =  String.isBlank(apexClass.NamespacePrefix) ? apexClass.Name : apexClass.NamespacePrefix + '.' + apexClass.Name
                    );
                    
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
                    
                    processes.add(process);
                }
            } catch (Exception e) {}
        }
        return processes;
    }
}