@isTest
private class IsChangedTest {

    private static testMethod void canDetermineConfigurable () {
        //arrange processes
        Process__c isChangedProcess = Processes.generateOne(IsChanged.class);
        
        //act
        String actualConfiguration = isChangedProcess.Configurable__c;
        
        // Assert
        String expectedConfiguration = Schema.SobjectType.IsChangedConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
        
    private static testMethod void callingIsChangedReturnsFalseOnFirstRun() {
        //arrange
        String lastHash01 = null ;
        String latestHash01 = '12345';
        String lastHash02 = 'abcde' ;
        String latestHash02 = '12345';
        Boolean firstRun = true;
        
        //act
        Boolean actualIsChanged01 = IsChanged.isChanged( lastHash01, latestHash01, firstRun);
        Boolean actualIsChanged02 = IsChanged.isChanged( lastHash02, latestHash02, firstRun);
        
        // Assert
        Boolean expected = false;
        System.assertEquals(expected, actualIsChanged01);
        System.assertEquals(expected, actualIsChanged02);
    }
    
    
    private static testMethod void callingIsChangedReturnsExpectedOnSecondRun() {
        //arrange
        String lastHash01 = '12345' ;
        String latestHash01 = '12345';
        String lastHash02 = 'abcde' ;
        String latestHash02 = '12345';
        Boolean firstRun = false;
        
        //act
        Boolean actualIsChanged01 = IsChanged.isChanged( lastHash01, latestHash01, firstRun);
        Boolean actualIsChanged02 = IsChanged.isChanged( lastHash02, latestHash02, firstRun);

        // Assert
        Boolean expected01 = false;
        Boolean expected02 = true;
        System.assertEquals(expected01, actualIsChanged01);
        System.assertEquals(expected02, actualIsChanged02);
    }
    
    private static testMethod void callingDeriveNewAttributesUpdatesAttributesCorrectly() {
        //arrange
        IsChangedConfiguration__c configuration = new IsChangedConfiguration__c();
        insert configuration;
        
        String value = '12345';
        Object obj = (Object) value;
        Map<string,Object> attributes = new Map<string,Object> {
            'object' => obj ,
            'configurationId' => configuration.Id,
            'newBlobId' => null,
            'newValueAsString' => null,
            'newHash' => null
        };
        
        //act
        IsChanged.deriveNewAttributes( attributes) ;
        
        //assemble
        String actualNewHash = (String) attributes.get('newHash');
        String actualNewValueAsString = ( String ) attributes.get('newValueAsString');
        Id actualNewBlobId = ( Id ) attributes.get('newBlobId');
        Blob valueAsBlob = Blob.valueOf( value );
        
        // Assert
        String expectedNewHash = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', valueAsBlob));
        String expectedNewValueAsString = value ;
        Id expectedNewBlobId = null ;
        System.assertEquals( expectedNewHash , actualNewHash );
        System.assertEquals( expectedNewValueAsString , actualNewValueAsString );
        System.assertEquals( expectedNewBlobId , actualNewBlobId );
    }
    
    private static testMethod void callingDeriveNewAttributesUpdatesAttributesCorrectlyForBlob01() {
        //arrange
        IsChangedConfiguration__c configuration = new IsChangedConfiguration__c();
        insert configuration;
        
        String value = '12345';
        Object obj = (Object) Blob.valueOf(value);
        Map<string,Object> attributes = new Map<string,Object> {
            'object' => obj ,
            'configurationId' => configuration.Id,
            'newBlobId' => null,
            'newValueAsString' => null,
            'newHash' => null
        };
        
        //act
        IsChanged.deriveNewAttributes( attributes) ;
        
        //assemble
        String actualNewHash = (String) attributes.get('newHash');
        String actualNewValueAsString = ( String ) attributes.get('newValueAsString');
        Id actualNewBlobId = ( Id ) attributes.get('newBlobId');
        Blob valueAsBlob = Blob.valueOf( value );
        List<Attachment> attachments = [SELECT Id, Name FROM Attachment WHERE ParentId = :configuration.Id];
        
        // Assert
        String expectedNewHash = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', valueAsBlob));
        String expectedNewValueAsString = null ;
        Integer expectedCount = 1;
        System.assertEquals( expectedNewHash , actualNewHash );
        System.assertEquals( expectedNewValueAsString , actualNewValueAsString );
        System.assertEquals( expectedCount , attachments.size() );
        System.assertEquals( attachments[0].Id , actualNewBlobId );
    }
    
    private static testMethod void callingDeriveNewAttributesUpdatesAttributesCorrectlyForBlob02() {
        //arrange
        IsChangedConfiguration__c configuration = new IsChangedConfiguration__c();
        insert configuration;
        
        Integer count = 0;
        Integer sizeBiggerThan255 = 280;
        String value = '';
        while (count < sizeBiggerThan255) {
            value = value + 'x';
            count++;
        }
        
        Object obj = (Object) value;
        Map<string,Object> attributes = new Map<string,Object> {
            'object' => obj ,
            'configurationId' => configuration.Id,
            'newBlobId' => null,
            'newValueAsString' => null,
            'newHash' => null
        };
        
        //act
        IsChanged.deriveNewAttributes( attributes) ;
        
        //assemble
        String actualNewHash = (String) attributes.get('newHash');
        String actualNewValueAsString = ( String ) attributes.get('newValueAsString');
        Id actualNewBlobId = ( Id ) attributes.get('newBlobId');
        Blob valueAsBlob = Blob.valueOf( value );
        List<Attachment> attachments = [SELECT Id, Name FROM Attachment WHERE ParentId = :configuration.Id];
        
        // Assert
        String expectedNewHash = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', valueAsBlob));
        String expectedNewValueAsString = null ;
        Integer expectedCount = 1;
        System.assertEquals( expectedNewHash , actualNewHash );
        System.assertEquals( expectedNewValueAsString , actualNewValueAsString );
        System.assertEquals( expectedCount , attachments.size() );
        System.assertEquals( attachments[0].Id , actualNewBlobId );
    }
    
    private static testMethod void callingInvokeReturnsZeroNoticationsWhenNoChangeFirstRun() {
        //arrange
        String theCurrentValue = '12345';
        String newValueToHash = theCurrentValue ; //-- same
        String oldValueToHash = theCurrentValue ; //-- same
        Blob newBlobValue = Blob.valueOf( newValueToHash );
        Blob oldBlobValue = Blob.valueOf( oldValueToHash );
        String newHashValue = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', newBlobValue));
        String oldHashValue = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', oldBlobValue));
        Account account = new Account (Name = 'Crow' , Jigsaw = theCurrentValue );
        insert account;
        String accountId = account.Id;
        
        //arrange processes
        Process__c isChangedProcess = Processes.generateOne(IsChanged.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'IsChangedChain');
        insert chain;
        
        //arrange steps
        Step__c step = Steps.generateOne(chain.Id, isChangedProcess.Id);
        
        IsChangedConfiguration__c configuration = [
        SELECT Id, NewHash__c, OldHash__c, NewBlobId__c, OldBlobId__c, NewValue__c, OldValue__c, FieldName__c
        FROM IsChangedConfiguration__c
        ];
        configuration.FieldName__c = 'Jigsaw';
        configuration.OldHash__c = null; //-- value before first run
        configuration.NewHash__c = null; //-- value before first run
        update configuration;

        Map<String,Object> parameters = new Map<String,Object>{
        'eda__configuration' => [SELECT id FROM IsChangedConfiguration__c].Id,
        'id' => accountId
        };
        
        //act
        IsChanged plugin = new IsChanged();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = Utility.convert(result);
        
        // Assert
        Integer expectedSize = 0; //-- same value , so expect zero
        Integer actualSize = results.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    private static testMethod void callingInvokeReturnsZeroNoticationsWhenNoChangeSecondRun() {
        //arrange
        String theCurrentValue = '12345';
        String newValueToHash = theCurrentValue ; //-- same
        String unchangedValueToHash = theCurrentValue ; //-- same
        Blob newBlobValue = Blob.valueOf( newValueToHash );
        Blob unchangedBlobValue = Blob.valueOf( unchangedValueToHash );
        String newHashValue = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', newBlobValue));
        String unchangedHashValue = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', unchangedBlobValue));
        Account account = new Account (Name = 'Crow' , Jigsaw = theCurrentValue );
        insert account;
        String accountId = account.Id;
        
        //arrange processes
        Process__c isChangedProcess = Processes.generateOne(IsChanged.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'IsChangedChain');
        insert chain;
        
        //arrange steps
        Step__c step = Steps.generateOne(chain.Id, isChangedProcess.Id);

        IsChangedConfiguration__c configuration = [
        SELECT Id, NewHash__c, OldHash__c, NewBlobId__c, OldBlobId__c, NewValue__c, OldValue__c, FieldName__c
        FROM IsChangedConfiguration__c
        ];
        configuration.FieldName__c = 'Jigsaw';
        configuration.OldHash__c = null; //-- value before second run
        configuration.NewHash__c = unchangedHashValue; //-- value before second run
        update configuration;
        
        
        Map<String,Object> parameters = new Map<String,Object>{
        'eda__configuration' => [SELECT id FROM IsChangedConfiguration__c].Id,
        'id' => accountId
        };
        
        //act
        IsChanged plugin = new IsChanged();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = Utility.convert(result);
        
        // Assert
        Integer expectedSize = 0; //-- same value , so expect zero
        Integer actualSize = results.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    
    private static testMethod void callingInvokeReturnsOneNoticationWhenChangeAndNotFirstRun() {
        //arrange
        String thePriorValue = 'abcde'; //-- diff
        String theCurrentValue = '12345'; //-- diff
        String priorValueToHash = thePriorValue ;
        String currentValueToHash = theCurrentValue ;
        Blob priorBlobValue = Blob.valueOf( priorValueToHash );
        Blob currentBlobValue = Blob.valueOf( currentValueToHash );
        String priorHashValue = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', priorBlobValue));
        String currentHashValue = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', currentBlobValue));
        Account account = new Account (Name = 'Crow' , Jigsaw = theCurrentValue );
        insert account;
        String accountId = account.Id;
        
        Process__c isChangedProcess = Processes.generateOne(IsChanged.class);
        
        Chain__c chain = new Chain__c(Name = 'IsChangedChain');
        insert chain;
        
        Step__c step = Steps.generateOne(chain.Id, isChangedProcess.Id);

        IsChangedConfiguration__c configuration = [
            SELECT Id, NewHash__c, OldHash__c, NewBlobId__c, OldBlobId__c, NewValue__c, OldValue__c, FieldName__c
        FROM IsChangedConfiguration__c
        ];
        
        configuration.FieldName__c = 'Jigsaw';
        configuration.OldHash__c = priorHashValue; //-- value before third run
        configuration.NewHash__c = priorHashValue; //-- value before third run
        update configuration;
        
        
        Map<String,Object> parameters = new Map<String,Object>{
        'eda__configuration' => [SELECT id FROM IsChangedConfiguration__c].Id,
        'id' => accountId
        };
        
        //act
        IsChanged plugin = new IsChanged();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = Utility.convert(result);
        
        // Assert
        Integer expectedSize = 1; //-- change detected , so expect one
        Integer actualSize = results.size();
        System.assertEquals(expectedSize, actualSize);
    }

    private static testMethod void callingDeleteOldAttachmentsDeletesExpectedAttachments() {
        //arrange
        IsChangedConfiguration__c configuration = new IsChangedConfiguration__c();
        insert configuration;

        Integer persistDurationInMinutes = 6;
        //+-----[NEW]
        //---- now --------------
        //---- very recent ------
		DateTime lastModifiedDate01 = System.Now().addMinutes( -1 * (persistDurationInMinutes-4) );
        //--- less recent -------
		DateTime lastModifiedDate02 = System.Now().addMinutes( -1 * (persistDurationInMinutes-2)  );
        //---- persistDurationInMinutes
        //---- very old ---------
		DateTime lastModifiedDate03 = System.Now().addMinutes( -1 * (persistDurationInMinutes+5)  );	
        //+-----[OLD]
            
        Attachment attachment01 = new Attachment(
            Name = 'IsChanged-' + lastModifiedDate01.format('YYYY-MM-DD HH:mm:ss').replace(' ','T'),
            Body = Blob.valueOf('balls'),
            ParentId = configuration.Id
        );
        insert attachment01;
 
		Attachment attachment02 = new Attachment(
			Name = 'IsChanged-' + lastModifiedDate02.format('YYYY-MM-DD HH:mm:ss').replace(' ','T'),
			Body = Blob.valueOf('balls'),
			ParentId = configuration.Id
		);
		insert attachment02;
		
		Attachment attachment03 = new Attachment(
			Name = 'IsChanged-' + lastModifiedDate03.format('YYYY-MM-DD HH:mm:ss').replace(' ','T'),
			Body = Blob.valueOf('balls'),
			ParentId = configuration.Id
		);
		insert attachment03;
 
        //act
        IsChanged.deleteOldAttachments(  persistDurationInMinutes) ;
        
        //assemble
        Map<Id,Attachment> attachmentIdToAttachment = new Map<Id,Attachment> ( [SELECT Id, Name FROM Attachment] );
        
        // Assert
		System.Assert(  attachmentIdToAttachment.keySet().contains(attachment01.Id) );
		System.Assert(  attachmentIdToAttachment.keySet().contains(attachment02.Id) );
		System.Assert( !attachmentIdToAttachment.keySet().contains(attachment03.Id) );
    }
}