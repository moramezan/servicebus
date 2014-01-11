@IsTest  
public class ApexClassesTest {
     private static testMethod void callingRegenerateReturnsExpectedProcesses() {
        //Arrange :
        String name1 = 'Sink';
        String name2 = 'Publish';
        List<String> names = new List<String>{name1, name2};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        
        // Act :
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        
        // Assert :
        Set<String> actualProcessNames = new Set<String>();
        for (Process__c  process : processes ) {
                actualProcessNames.add(process.Name);
        }
        
        String expectedName1 = name1;
        System.assert(actualProcessNames.contains(expectedName1));
        String expectedName2 = name2;
        System.assert(actualProcessNames.contains(expectedName2));
     }
}