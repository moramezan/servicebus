public class ProcessApexClassExtension {
    public class ProcessApexClassExtensionException extends Exception {}
    
    private ApexPages.StandardController controller;
    private Id processId;
    
    public ProcessApexClassExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        processId = controller.getId();
    }
 
    public System.PageReference ViewPage() {
        List<Process__c> processes = [SELECT FullyQualifiedClassName__c FROM Process__c WHERE Id = :processId];
        if (processes.size() == 0) { 
            throw new ProcessApexClassExtensionException('Cannot determine fully qualified class name from process id =['+processId+']');
        }
        
        String fullyQualifiedClassName  = processes[0].FullyQualifiedClassName__c;
        if (String.IsBlank(fullyQualifiedClassName)) { 
            throw new ProcessApexClassExtensionException('Cannot determine fully qualified class name from empty field on process id =['+processId+']');
        }     
        
        String namespacePrefix;
        String name;
        
        if (fullyQualifiedClassName.contains('.')) {
            //managed (namespaceprefix.classname)
            namespacePrefix = fullyQualifiedClassName.substringBefore('.');
            name = fullyQualifiedClassName.substringAfter('.');
        } else {
            //unmanaged (classname)
            namespacePrefix = '';
            name = fullyQualifiedClassName;
        }
        
        String query = 'SELECT Id FROM ApexClass WHERE NamespacePrefix = :namespacePrefix AND Name = :name';
        List<ApexClass> apexClasses = Database.query(query);
        
        if (apexClasses.size() == 0) { 
            throw new ProcessApexClassExtensionException('Cannot derive apex class from [' + fullyQualifiedClassName + ']');
        }
        
        Id apexClassId  = apexClasses[0].Id;

        return new PageReference('/' + apexClassId);
    }
}