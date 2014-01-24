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
        String theCurrentValue = '12345';
        String newValueToHash = theCurrentValue ; //-- same 
        String oldValueToHash = theCurrentValue ; //-- same 
        Blob newBlobValue = Blob.valueOf( newValueToHash );
        Blob oldBlobValue = Blob.valueOf( oldValueToHash );      
        String newHashValue  = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', newBlobValue));
        String oldHashValue  = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', oldBlobValue));
        Account account = new Account (Name = 'Crow' , Jigsaw = theCurrentValue );
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
            SELECT Id, NewHash__c, OldHash__c, NewId__c, OldId__c, NewValue__c, OldValue__c, FieldName__c
            FROM IsChangedConfiguration__c
        ];
        configuration.FieldName__c = 'Jigsaw';
        configuration.OldHash__c = newHashValue;
        configuration.NewHash__c = newHashValue;     
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
        Integer expectedSize = 0;  //-- same value , so expect zero
        Integer actualSize = results.size();     
        System.assertEquals(expectedSize, actualSize);  
    }  


    private static  testMethod void callingInvokeReturnsOneNoticationWhenThereIsAChange() {
        //arrange
        String theCurrentValue = '67890';
        String thePriorValue = '12345';
        String newValueToHash = theCurrentValue ; //-- diff 
        String oldValueToHash = thePriorValue ; //-- diff 
        Blob newBlobValue = Blob.valueOf( newValueToHash );
        Blob oldBlobValue = Blob.valueOf( oldValueToHash );      
        String newHashValue  = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', newBlobValue));
        String oldHashValue  = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', oldBlobValue));
        Account account = new Account (Name = 'Crow' , Jigsaw = theCurrentValue );
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
            SELECT Id, NewHash__c, OldHash__c, NewId__c, OldId__c, NewValue__c, OldValue__c, FieldName__c
            FROM IsChangedConfiguration__c
        ];
        configuration.FieldName__c = 'Jigsaw';
        configuration.OldHash__c = oldHashValue;
        configuration.NewHash__c = oldHashValue; 
        configuration.OldValue__c = oldValueToHash;
        configuration.NewValue__c = oldValueToHash;   
        configuration.OldId__c = accountId;
        configuration.NewId__c = accountId; 
        update configuration;
        
        Map<String,Object> notification = new Map<String,Object>{
            'eda__configuration' => [SELECT id FROM IsChangedConfiguration__c].Id,
            'id' => accountId
        };

        //act
        IsChanged plugin = new IsChanged();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> results = Utility.convert(result);
        
        //assemble
        IsChangedConfiguration__c configurationAfter = [
            SELECT Id, NewHash__c, OldHash__c, NewId__c, OldId__c, NewValue__c, OldValue__c, FieldName__c
            FROM IsChangedConfiguration__c
        ];

        // Assert
        String expectedNewHash = newHashValue;
        String actualNewHash = configurationAfter.NewHash__c;     
        System.assertEquals(expectedNewHash, actualNewHash);         
        
        String expectedOldHash = oldHashValue;
        String actualOldHash = configurationAfter.OldHash__c;     
        System.assertEquals(expectedOldHash, actualOldHash);  
        
        String expectedNewValue = theCurrentValue;
        String actualNewValue = configurationAfter.NewValue__c;     
        System.assertEquals(expectedNewValue, actualNewValue);         
        
        String expectedOldValue = thePriorValue;
        String actualOldValue = configurationAfter.OldValue__c;     
        System.assertEquals(expectedOldValue, actualOldValue); 

        String expectedNewId = accountId;
        String actualNewId = configurationAfter.NewId__c;     
        System.assertEquals(expectedNewId, actualNewId);         
        
        String expectedOldId = accountId;
        String actualOldId = configurationAfter.OldId__c;     
        System.assertEquals(expectedOldId, actualOldId);  
 
        Integer expectedSize = 1; //-- new value , so expect one
        Integer actualSize = results.size();     
        System.assertEquals(expectedSize, actualSize);  
    }

    private static  testMethod void callingGetIsBlobTypeReturnsFalseWhenFieldInNotBlob() {
        //arrange
        String  value = '123456789012345';
        SObject obj  = new Account(Name ='Balls', Jigsaw = value) ; 
        String fieldName = Schema.SObjectType.Account.Fields.Jigsaw.Name;

        //act
        Boolean actualIsBlobType = IsChanged.getIsBlobType( obj,  fieldName) ;
 
        // Assert       
        Boolean expectedIsBlobType = false;    
        System.assertEquals(expectedIsBlobType, actualIsBlobType);  
    }

     private static  testMethod void callingGetIsBlobTypeReturnsTrueWhenFieldIsBlob() {
        //arrange
        String  value = '123456789012345';
         
        Account account = new Account(Name ='Balls');
        insert account;
 
        SObject obj  = new Attachment(
            Name = 'test-attachment',
            Body = Blob.valueOf(value),
            ParentId = account.Id,
            ContentType = 'application/zip'
        );
         insert obj;
        String fieldName = Schema.SObjectType.Attachment.Fields.Body.Name;

        //act
        Boolean actualIsBlobType = IsChanged.getIsBlobType( obj,  fieldName) ;
 
        // Assert       
        Boolean expectedIsBlobType = true;    
        System.assertEquals(expectedIsBlobType, actualIsBlobType);  
    }
    
    private static  testMethod void callingGetNewValueReturnExpectedValueWhenFieldIsNotBlob() {
        //arrange
        String  value = '123456789012345';
        Integer maxValueSize = 6;
        SObject obj  = new Account(Name ='Balls', Jigsaw = value) ; 
        String fieldName = Schema.SObjectType.Account.Fields.Jigsaw.Name;

        //act
        String actualNewValue = IsChanged.getNewValue(  obj,   fieldName,   maxValueSize);
  
 
        // Assert       
        String  expectedNewValue = value.left(maxValueSize);   
        System.assertEquals(expectedNewValue, actualNewValue);  
    }  
    
    private static  testMethod void callingGetNewValueReturnExpectedValueWhenFieldIsABlob() {
        //arrange
        String  value = '123456789012345';
        Integer maxValueSize = 50;
        Account account = new Account(Name ='Balls');
        insert account;
         Blob blobValue = Blob.valueOf(value);
        
        SObject obj  = new Attachment(
            Name = 'test-attachment',
            Body = blobValue,
            ParentId = account.Id
        );
        insert obj;
        String fieldName = Schema.SObjectType.Attachment.Fields.Body.Name; 
        
        //act
        String actualNewValue = IsChanged.getNewValue(  obj,   fieldName,   maxValueSize);
 
        // Assert  
        String expectedNewValue  = EncodingUtil.base64Encode(blobValue).left(maxValueSize);   
        System.assertEquals(expectedNewValue, actualNewValue);  
    } 
    
}