@isTest
private class IsChangedTest {
  
    private static  testMethod void canDetermineConfigurable () {
        //arrange
        String  className  = 'IsChanged';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        
        //act
        String actualConfiguration = processes[0].Configurable__c;
        
        // Assert
        String expectedConfiguration = Schema.SobjectType.IsChangedConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);  
    }

    private static  testMethod void callingInvokeReturnsZeroNoticationsWhenNoChange() {
        //arrange
        String valueToHash = '12345' ;
        Blob value = Blob.valueOf( valueToHash );
        String hashedValue  = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', value));
        Account account = new Account (Name = 'Crow' , Jigsaw = valueToHash );
        insert account;
        String accountId  = account.Id;
 
        String  className  = 'IsChanged';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
       	Process__c isChangedProcess = processes[0];
        insert processes;

        Chain__c chain = new Chain__c(Name = 'IsChangedChain');
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = isChangedProcess.Id);
        insert chainStep;


        IsChangedConfiguration__c configuration = [
            SELECT Id, FieldName__c, LastHash__c 
            FROM IsChangedConfiguration__c
        ];
        configuration.FieldName__c = 'Jigsaw';
        configuration.LastHash__c = hashedValue;
        update configuration;
        
        Map<String,Object> notification = new Map<String,Object>{
            'eda__configuration' => [SELECT id FROM IsChangedConfiguration__c].Id,
            'id' => accountId
        };

        //act
        IsChanged plugin = new IsChanged();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> results = Utility.convert(result);

        // Assert
        Integer expectedSize = 0;  //-- same value , so expect zer0 
        Integer actualSize = results.size();     
        System.assertEquals(expectedSize, actualSize);  
    }  


    private static  testMethod void callingInvokeReturnsOneNoticationWhenThereIsAChange() {
        //arrange
        String valueToHash = '12345' ;
        String newValue    = '67890' ;
        Blob value = Blob.valueOf( valueToHash );
        String hashedValue  = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', value));
        Account account = new Account (Name = 'Crow' , Jigsaw = newValue);
        insert account;
        String accountId  = account.Id;
 
        String  className  = 'IsChanged';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
       	Process__c isChangedProcess = processes[0];
        insert processes;

        Chain__c chain = new Chain__c(Name = 'IsChangedChain');
        insert chain;
        
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = isChangedProcess.Id);
        insert chainStep;

        IsChangedConfiguration__c configuration = [
            SELECT Id, FieldName__c, LastHash__c 
            FROM IsChangedConfiguration__c
        ];
        configuration.FieldName__c = 'Jigsaw';
        configuration.LastHash__c = hashedValue;
        update configuration;
        
        Map<String,Object> notification = new Map<String,Object>{
            'eda__configuration' => [SELECT id FROM IsChangedConfiguration__c].Id,
            'id' => accountId
        };

        //act
        IsChanged plugin = new IsChanged();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> results = Utility.convert(result);
 
        // Assert
        Integer expectedSize = 1;       //-- new value , so expect one 
        Integer actualSize = results.size();     
        System.assertEquals(expectedSize, actualSize);  
    }  
    
    
}