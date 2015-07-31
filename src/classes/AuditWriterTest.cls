@IsTest private class AuditWriterTest{

    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 50;
        Integer actualLimits = new AuditWriter.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
    
    private static testmethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessEntryPointUuid() {
        //arrange
        String sequenceName  = 'AuditWriterSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA';
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
    
        Map<String,Object> event = new Map<String,Object>{
            // '__EntryPointUuid' => '1234567abcde',  // null EntryPointUuid
            'esb__Id' => theId
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            ApexClassModel.BaseProcess process = new AuditWriter();
            List<Map<String,Object>> results = process.execute(event);
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
      
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException);
        
        String expectedMessage = 'Unable to access the Entry Point UUID';
        System.assert( actualMessage.contains(expectedMessage) );
    }
    
    private static testmethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessStep() {
        //arrange
        String sequenceName  = 'AuditWriterSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA';
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
    
        Map<String,Object> event = new Map<String,Object>{
            '__EntryPointUuid' => '1234567abcde',
            'esb__Id' => theId
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            ApexClassModel.BaseProcess process = new AuditWriter();
            List<Map<String,Object>> results = process.execute(event);
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
      
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException);
        
        String expectedMessage = 'Unable to access the Step';
        System.assert( actualMessage.contains(expectedMessage) );
    }

    private static testmethod void callingInvokeInsertsExpectedAuditWriterEntries() {
        //arrange
        String theIdentifier1 = 'BALLS';
        String theIdentifier2 = 'CROW';
       
        String sequenceName  = 'AuditSequence';
        Integer positionA2 =  1;
        Id theId  = '000000000000000AAA';
               
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c stepA2 = SequenceModel.fromName(sequence.Name).appendStep(AuditInitializer.class);
 
        AuditInitializerConfig__c config1  = new AuditInitializerConfig__c(
            StaticGroupIdentifier__c = theIdentifier1
        );
        insert config1;
         
        AuditInitializerConfig__c config2  = new AuditInitializerConfig__c(
            StaticGroupIdentifier__c = theIdentifier2
        );
        insert config2;
        
        AuditGroup__c auditGroup1  = new AuditGroup__c(
            AuditInitializerConfig__c = config1.Id,
            GroupIdentifier__c =  theIdentifier1,
            Stamp__c = System.Now()
        );
        insert auditGroup1;
        
        AuditGroup__c auditGroup2  = new AuditGroup__c(
            AuditInitializerConfig__c = config2.Id,
            GroupIdentifier__c =  theIdentifier2,
            Stamp__c = System.Now()
        );
        insert auditGroup2;
 
        List<Object> auditGroupIds = new List<Object>{ auditGroup1.Id, auditGroup2.Id };
 
        Map<String,Object> event = new Map<String,Object>{
            'esb__Id' => theId,
            '__EntryPointUuid' => '1234567abcde',
            '__AuditGroupIds' => auditGroupIds,
            '__SequenceName' => sequenceName,
            '__Position' => positionA2
        };
        
        //act
        ApexClassModel.BaseProcess process = new AuditWriter();
        List<Map<String,Object>> results = process.execute(event);
        
        //assemble
        List<AuditEntry__c> auditEntries = ApexDomain.listAll(AuditEntry__c.SObjectType);
        
         
        Boolean actualAuditGroup1 = false;
        Boolean actualAuditGroup2 = false;
        String actualEventSerialized1;
        String actualEventSerialized2;
        for (AuditEntry__c  auditEntry : auditEntries) {
            if (auditEntry.AuditGroup__c == auditGroup1.Id) {
                actualAuditGroup1 = true;
                actualEventSerialized1 = auditEntry.Event__c;
            }
            if (auditEntry.AuditGroup__c == auditGroup2.Id) {
                actualAuditGroup2 = true;
                actualEventSerialized2 = auditEntry.Event__c;
            }
        }
        String actualSequenceName;
        Boolean actualEvent = ( actualEventSerialized2 != null);
 
        
            
        // Assert
        Integer expectedResultsSize = 1;
        Integer actualResultsSize = results.size();
        System.assertEquals(expectedResultsSize, actualResultsSize);
        
        Integer expectedAuditEntrySize = 2;
        Integer actualAuditEntrySize = AuditEntries.size();
        System.assertEquals(expectedAuditEntrySize, actualAuditEntrySize);

        Boolean expectedAuditGroup1 = true;
        Boolean expectedAuditGroup2 = true;
        Boolean expectedEvent = true;
        String expectedSequenceName = sequenceName;
        System.assertEquals(expectedAuditGroup1, actualAuditGroup1);
        System.assertEquals(expectedAuditGroup2, actualAuditGroup2);
        System.assertEquals(expectedEvent, actualEvent);
        System.assertEquals(actualEventSerialized1, actualEventSerialized2);
        System.assert(actualEventSerialized1.contains(expectedSequenceName));
    }

}