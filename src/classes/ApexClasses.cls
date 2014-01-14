public class ApexClasses extends SObjects {

    public class Metadata {
        public SObject customizable;
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
            try {
                Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
                Process.Plugin plugin = (Process.Plugin)reflector.newInstance();
                if (plugin instanceof Database.Stateful) {
                    Process.PluginDescribeResult describeResult = plugin.describe();
                    String tag = describeResult.Tag;
                    String description = describeResult.Description;
                    String customizable;
                    String configurable;
                    
                    Type metadataReflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name + '.' + 'Metadata');
                    if (metadataReflector != null) {
                        //if eg Eda.Wiretap.Metadata inner class exists, cast it into our instance from upstairs
                        Metadata meta = (Metadata)Json.deserialize(Json.serialize(metadataReflector.newInstance()), Metadata.class);
                        
                        if (meta.customizable != null) {
                            //attempt to populate the name of the customization object
                            customizable = meta.customizable.getSObjectType().getDescribe().getName();
                        }
                        
                        if (meta.configurable != null) {
                            //attempt to populate the name of the configuration object
                            configurable = meta.configurable.getSObjectType().getDescribe().getName();
                        }
                    }
                    
                    Process__c process = new Process__c(
                        Name = reflector.getName(),
                        Description__c = description,
                        Tag__c = tag,
                        Customizable__c = customizable,
                        Configurable__c = configurable
                    );
                    processes.add(process);
                }
            } catch (Exception e) {
                //non-implementors can fail hard
            }
        }
        return processes;
    }
    
    private static Map<string, string> getMetaMap(string ns, string className) {
        Map<string, string> keyToValue = new Map<string, string>();
        Type metaReflector = Type.forName(ns, className);
        try {
            List<String> metas = String.valueOf(metaReflector.newInstance()).substringBefore(']').substringAfter('[').split(',');
            
            for (String  meta : metas) {
                List<String> values = meta.split('=');
                if (values.size()==2) {
                    keyToValue.put(values[0], values[1]);    
                }
            }
        } catch (Exception e) {
            // fail silently 
        }
        
        return keyToValue;
    }
}