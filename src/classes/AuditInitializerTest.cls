@IsTest private class AuditInitializerTest {

    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 75;
        Integer actualLimits = new AuditInitializer.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }


    private static testmethod void canDetermineStepConfig() {
        //arrange processes
        Process__c auditInitializerProcess = ProcessModel.generateOne(AuditInitializer.class);
        
        //act
        String actualConfig = auditInitializerProcess.StepConfig__c;
        
        // Assert
        String expectedConfig = Schema.SobjectType.AuditInitializerConfig__c.Name;
        System.assertEquals(expectedConfig, actualConfig);
    }
    
    private static testmethod void callingInvokeInsertsExpectedCompositeIdentifiersOnAuditGroupForXXXXXXXXX() {
        //arrange
        String sequenceName  = 'AuditInitializerSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA'; // no data present
        Process__c auditInitializerProcess = ProcessModel.generateOne(AuditInitializer.class);
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step = new Step__c(Sequence__c = sequence.Id, Position__c = thePosition, Process__c = auditInitializerProcess.Id);
        insert step;
        
        AuditInitializerConfig__c config = [
            SELECT Id, StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        config.StaticGroupIdentifier__c = null;
        config.DynamicGroupIdentifier__c = 'Fld_Doesnt_Exist__c';
        update config;
        
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__StepConfig' => config,
            'esb__Id' => theId,
            '__SequenceName' => sequenceName,
            '__Position' => thePosition
        };
        
        //act
        ProcessModel.BaseProcess process = new AuditInitializer();
        List<Map<String,Object>> results = process.execute(parameters);
        
        //assemble
        DateTime expectedStampTo = System.Now().addSeconds(1);
        DateTime expectedStampFrom = System.Now().addSeconds(-1);
        List<AuditGroup__c> auditGroups = [
            SELECT id, Name, AuditInitializerConfig__c,  GroupIdentifier__c, Stamp__c
            FROM AuditGroup__c
            WHERE Stamp__c >= :expectedStampFrom
            AND Stamp__c <=  :expectedStampTo
        ];

        String  actualGroupIdentifier = null;
        Integer actualAuditGroupSize = auditGroups.size();
        if (actualAuditGroupSize > 0) {
             actualGroupIdentifier =  auditGroups[0].GroupIdentifier__c;
        }
        
           
        // Assert
        Integer expectedResultsSize = 1;
        Integer actualResultsSize = results.size();
        System.assertEquals(expectedResultsSize, actualResultsSize);
        
        Integer expectedAuditGroupSize = 1;
        System.assertEquals(expectedAuditGroupSize, actualAuditGroupSize);
        
        String expectedGroupIdentifier1 = 'DYNAMIC-KEY-ON';
        System.assert(actualGroupIdentifier.contains(expectedGroupIdentifier1));
    }
    
    private static testmethod void callingInvokeInsertsExpectedCompositeIdentifiersOnAuditGroupForConfigIdentifierEqNull() {
        //arrange
        String sequenceName  = 'AuditInitializerSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA';
        Process__c auditInitializerProcess = ProcessModel.generateOne(AuditInitializer.class);
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step = new Step__c(Sequence__c = sequence.Id, Position__c = thePosition, Process__c = auditInitializerProcess.Id);
        insert step;
        
        AuditInitializerConfig__c config = [
            SELECT Id, StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        config.StaticGroupIdentifier__c = null; // no identifier specified
        update config;
        
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__StepConfig' => config,
            'esb__Id' => theId,
            '__SequenceName' => sequenceName,
            '__Position' => thePosition
        };
        
        //act
        ProcessModel.BaseProcess process = new AuditInitializer();
        List<Map<String,Object>> results = process.execute(parameters);
        
        //assemble
        DateTime expectedStampTo = System.Now().addSeconds(1);
        DateTime expectedStampFrom = System.Now().addSeconds(-1);
        List<AuditGroup__c> auditGroups = [
            SELECT id, Name, AuditInitializerConfig__c,  GroupIdentifier__c, Stamp__c
            FROM AuditGroup__c
            WHERE Stamp__c >= :expectedStampFrom
            AND Stamp__c <=  :expectedStampTo
        ];

        String  actualGroupIdentifier = null;
        Integer actualAuditGroupSize = auditGroups.size();
        if (actualAuditGroupSize > 0) {
             actualGroupIdentifier =  auditGroups[0].GroupIdentifier__c;
        }
        
           
        // Assert
        Integer expectedResultsSize = 1;
        Integer actualResultsSize = results.size();
        System.assertEquals(expectedResultsSize, actualResultsSize);
        
        Integer expectedAuditGroupSize = 1;
        System.assertEquals(expectedAuditGroupSize, actualAuditGroupSize);
        
        String expectedGroupIdentifier1 = sequenceName ;
        String expectedGroupIdentifier2 = String.valueOf(thePosition) ;
        System.assert(actualGroupIdentifier.contains(expectedGroupIdentifier1));
        System.assert(actualGroupIdentifier.contains(expectedGroupIdentifier2));
    }
    
    
    private static testmethod void callingInvokeInsertsExpectedCompositeIdentifiersOnAuditGroupForConfigIdentifierNotNull() {
        //arrange
        String theIdentifier  = 'BALLS-SAID';
        String sequenceName  = 'AuditInitializerSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA';
        Process__c auditInitializerProcess = ProcessModel.generateOne(AuditInitializer.class);
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step = new Step__c(Sequence__c = sequence.Id, Position__c = thePosition, Process__c = auditInitializerProcess.Id);
        insert step;
        
        AuditInitializerConfig__c config = [
            SELECT Id, StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        config.StaticGroupIdentifier__c = theIdentifier; // not null
        update config;
        
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__StepConfig' => config,
            'esb__Id' => theId,
            '__SequenceName' => sequenceName,
            '__Position' => thePosition
        };
        
        //act
        ProcessModel.BaseProcess process = new AuditInitializer();
        List<Map<String,Object>> results = process.execute(parameters);
        
        //assemble
        DateTime expectedStampTo = System.Now().addSeconds(1);
        DateTime expectedStampFrom = System.Now().addSeconds(-1);
        List<AuditGroup__c> auditGroups = [
            SELECT id, Name, AuditInitializerConfig__c,  GroupIdentifier__c, Stamp__c
            FROM AuditGroup__c
            WHERE Stamp__c >= :expectedStampFrom
            AND Stamp__c <=  :expectedStampTo
        ];

        String  actualGroupIdentifier = null;
        Integer actualAuditGroupSize = auditGroups.size();
        if (actualAuditGroupSize > 0) {
             actualGroupIdentifier =  auditGroups[0].GroupIdentifier__c;
        }
        
           
        // Assert
        Integer expectedResultsSize = 1;
        Integer actualResultsSize = results.size();
        System.assertEquals(expectedResultsSize, actualResultsSize);
        
        Integer expectedAuditGroupSize = 1;
        System.assertEquals(expectedAuditGroupSize, actualAuditGroupSize);
        
        String expectedGroupIdentifier1 = theIdentifier ;
        System.assert(actualGroupIdentifier.contains(expectedGroupIdentifier1));
    }

    private static testmethod void callingGetHydratedThrowsExpectedExceptionWhenIdInvalid() {
        //arrange
        Id bullshitId = '000000000000000AAA';

        //act
        String actualMessage;
        Boolean actualExceptionFlag  = false;
        try {
            SObject o = AuditInitializer.getHydrated(bullshitId);
        } catch (Exception e ) {
            actualMessage = e.getMessage();
            actualExceptionFlag  = true;
        }
  
        // assert
        Boolean expectedExceptionFlag  = true;
        String expectedMessage = 'Cannot hydate SObject';
        System.assertEquals( actualExceptionFlag, expectedExceptionFlag );
        System.assert( actualMessage.contains(expectedMessage) );
    }
                            
    private static testmethod void callingGetHydratedReturnsFullyHydratedSObject() {
        //arrange
        String theName = 'BALLS';
        String theJigSaw = '12345';
        Account account = new Account(Name = theName, JigSaw = theJigSaw);
        insert account;
        Id theId = account.Id;

        //act
        SObject o = AuditInitializer.getHydrated(theId);
 
        // assemble
        String actualMessage  = json.serialize(o);
        
        // assert
        String expectedMessage1 = theName;
        String expectedMessage2 = theJigSaw;
        System.assert( actualMessage.contains(expectedMessage1) );
        System.assert( actualMessage.contains(expectedMessage2) );
    }

    
   private static testmethod void callingGetIdentiferReturnsExpectedIdentifier() {
        //arrange
        String theName = 'BALLS';
        String theJigsaw = '12345';
        SObject so = new Account(Name = theName, Jigsaw = theJigsaw);
        String fieldName = 'Jigsaw';

        //act
        String actualIdentifier = AuditInitializer.getIdentifer(fieldName ,so);
      
        // assert
        String expectedIdentifier = theJigSaw;
        System.assertEquals(expectedIdentifier, actualIdentifier);
    }
}