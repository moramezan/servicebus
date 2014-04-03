public class ProcessApexClassExtension {
    public class ProcessApexClassExtensionException extends Exception {}
    
    private ApexPages.StandardController controller;
    private Id processId;
    
    public ProcessApexClassExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        processId = controller.getId();
    }
 
    public System.PageReference ViewPage() {
        Process__c proc;
        try {
            proc = (Process__c)SalesforceObject.getById(this.processId);
        } catch (System.QueryException e) {
            throw new ProcessApexClassExtensionException('Cannot determine fully qualified class name from process id =['+this.processId+']');
        }
        
        String fullyQualifiedClassName  = proc.FullyQualifiedClassName__c;
        if (String.IsBlank(fullyQualifiedClassName)) { 
            throw new ProcessApexClassExtensionException('Cannot determine fully qualified class name from empty field on process id =['+this.processId+']');
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