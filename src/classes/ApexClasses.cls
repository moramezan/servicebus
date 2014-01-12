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
                    String description = (describeResult.Description != null) ? describeResult.Description.substringBefore('{') : null;
                    Process__c process = new Process__c(
                        Name = reflector.getName(),
                        Description__c = description,
                        Tag__c = describeResult.Tag
                    );
                    processes.add(process);
                }
            } catch (Exception e) {
                //non-implementors can fail hard
            }
        }
        return processes;
    }
}