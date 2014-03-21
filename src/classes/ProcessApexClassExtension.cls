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
        
        String clause;
        if (fullyQualifiedClassName.contains('.')) {
            //managed (namespaceprefix.classname)
            clause = '(NamespacePrefix = \'' + fullyQualifiedClassName.substringAfter('.') + '\' AND Name = \'' + fullyQualifiedClassName.substringAfter('.') + '\')';
        } else {
            //unmanaged (classname)
            clause = '(Name = \'' + fullyQualifiedClassName + '\')';
        }   
        List<SOBject> apexClasses = Database.query('SELECT Id FROM ApexClass WHERE ' + clause);
        if (apexClasses.size() == 0) { 
            throw new ProcessApexClassExtensionException('Cannot derive apex class from ['+clause+']');
        }
        
        Id apexClassId  = apexClasses[0].Id;

        return new PageReference('/' + apexClassId);
    }
}