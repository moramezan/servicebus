@IsTest  
private class ApexClassesTest {
    private static testMethod void callingRegenerateReturnsExpectedConfigurable() {
        //Arrange :
        String name1 = 'Publish';
        List<String> names = new List<String>{name1};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        
        // Act :
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        
        // Assert :
        Integer expectedSize = 1; 
        Integer actualSize = processes.size();
        System.assertEquals (expectedSize, actualSize); 
        
        String expectedConfigurable = PublishConfiguration__c.class.getName();
        String actualConfigurable = processes[0].Configurable__c;    
        System.assertEquals(expectedConfigurable, actualConfigurable);
     }
   
    
    private static testMethod void callingRegenerateReturnsExpectedCustomizable() {
        //Arrange :
        String name1 = 'Wiretap';
        List<String> names = new List<String>{name1};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        
        // Act :
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        
        // Assert :
        Integer expectedSize = 1; 
        Integer actualSize = processes.size();
        System.assertEquals (expectedSize, actualSize); 
        
        String expectedCustomizable = WiretapCustomization__c.class.getName();
        String actualCustomizable = processes[0].Customizable__c;    
        System.assertEquals(expectedCustomizable, actualCustomizable);
     }
    
    
    private static testMethod void callingRegenerateReturnsExpectedProcesses() {
        //Arrange :
        String name1 = 'Terminate';
        String name2 = 'Publish';
        List<String> names = new List<String>{name1, name2};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        
        // Act :
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        
        // Assert :
        Set<String> actualProcessNames = new Set<String>();
        Set<String> actualProcessQualifiedNames = new Set<String>();
        for (Process__c  process : processes ) {
                actualProcessNames.add(process.Name);
                actualProcessQualifiedNames.add(process.FullyQualifiedClassName__c);          
        }
        
        String expectedName1 = name1;
        System.assert(actualProcessNames.contains(expectedName1));
        String expectedName2 = name2;
        System.assert(actualProcessNames.contains(expectedName2));
 
        System.assert(actualProcessQualifiedNames.contains(expectedName1));
        System.assert(actualProcessQualifiedNames.contains(expectedName2));        
     }
}