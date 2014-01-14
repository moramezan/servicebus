public class ApexClasses extends SObjects {

    public ApexClasses(List<ApexClass> apexClasses) {
        super(apexClasses);
    }
    
    public List<Process__c> regenerate() {
        List<ApexClass> apexClasses = (List<ApexClass>)this.getSObjects();
        List<Process__c> processes = new List<Process__c>();

        for (ApexClass apexClass : apexClasses) {
            try {
                Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
                Process.Plugin plugin = (Process.Plugin)reflector.newInstance();
                if (plugin instanceof Database.Stateful) {
                    Process.PluginDescribeResult describeResult = plugin.describe();
                    String description = describeResult.Description;
                    
                    //TODO :: json serialize serialize untyped map not working - work around ...
                    Map<string, string> keyToValue = getMetaMap(apexClass.NamespacePrefix, apexClass.Name + '.' + 'Metadata');
                    String customizable = keyToValue.get('customizable');
                    String configurable = keyToValue.get('configurable');
                    Process__c process = new Process__c(
                        Name = reflector.getName(),
                        Description__c = description,
                        Tag__c = describeResult.Tag,
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