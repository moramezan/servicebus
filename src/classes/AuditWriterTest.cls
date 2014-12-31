@IsTest private class AuditWriterTest{

    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 50;
        Integer actualLimits = new AuditWriter.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
    
    private static testmethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessEntryPointGuid() {
        //arrange
        String sequenceName  = 'AuditWriterSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA';
        Process__c auditWriterProcess = ProcessObject.generateOne(AuditWriter.class);
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
    
        Map<String,Object> parameters = new Map<String,Object>{
            // '__EntryPointGuid' => '1234567abcde',  // null EntryPointGuid
            'esb__Id' => theId
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            Type reflector = AuditWriter.class;
            List<Map<String,Object>> results = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;
        } catch (Exception e) {
            actualFlagException =  true;
            actualMessage = e.getMessage();
        }
      
        // Assert
        Boolean expectedFlagException = true;
        System.assertEquals(expectedFlagException, actualFlagException);
        
        String expectedMessage = 'Unable to access the Entry Point GUID';
        System.assert( actualMessage.contains(expectedMessage) );
    }
    
    private static testmethod void callingInvokeThrowsExpectedExceptionWhenCannotAccessStep() {
        //arrange
        String sequenceName  = 'AuditWriterSequence';
        Integer thePosition =  1;
        Id theId  = '000000000000000AAA';
        Process__c auditWriterProcess = ProcessObject.generateOne(AuditWriter.class);
        
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
    
        Map<String,Object> parameters = new Map<String,Object>{
            '__EntryPointGuid' => '1234567abcde',
            'esb__Id' => theId
        };
        
        //act
        Boolean actualFlagException =  false;
        String actualMessage;
        try {
            Type reflector = AuditWriter.class;
            List<Map<String,Object>> results = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;
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
        Process__c auditWriterProcess = ProcessObject.generateOne(AuditWriter.class);
               
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c stepA2 = new Step__c(Sequence__c = sequence.Id, Position__c = positionA2, Process__c = auditWriterProcess.Id);
        insert stepA2;
 
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
 
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__Id' => theId,
            '__EntryPointGuid' => '1234567abcde',
            'esb__AuditGroupIds' => auditGroupIds,
            '__SequenceName' => sequenceName,
            '__Position' => positionA2
        };
        
        //act
        Type reflector = AuditWriter.class;
        List<Map<String,Object>> results = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;
        
        //assemble
        List<AuditEntry__c> auditEntries = SalesforceObjectSet.listAll(AuditEntry__c.SObjectType);
        
         
        Boolean actualAuditGroup1 = false;
        Boolean actualAuditGroup2 = false;
        String actualParametersSerialized1;
        String actualParametersSerialized2;
        for (AuditEntry__c  auditEntry : auditEntries) {
            if (auditEntry.AuditGroup__c == auditGroup1.Id) {
                actualAuditGroup1 = true;
                actualParametersSerialized1 = auditEntry.Parameters__c;
            }
            if (auditEntry.AuditGroup__c == auditGroup2.Id) {
                actualAuditGroup2 = true;
                actualParametersSerialized2 = auditEntry.Parameters__c;
            }
        }
        String actualSequenceName;
        Boolean actualParameters = ( actualParametersSerialized2 != null);
 
        
            
        // Assert
        Integer expectedResultsSize = 1;
        Integer actualResultsSize = results.size();
        System.assertEquals(expectedResultsSize, actualResultsSize);
        
        Integer expectedAuditEntrySize = 2;
        Integer actualAuditEntrySize = AuditEntries.size();
        System.assertEquals(expectedAuditEntrySize, actualAuditEntrySize);

        Boolean expectedAuditGroup1 = true;
        Boolean expectedAuditGroup2 = true;
        Boolean expectedParameters = true;
        String expectedSequenceName = sequenceName;
        System.assertEquals(expectedAuditGroup1, actualAuditGroup1);
        System.assertEquals(expectedAuditGroup2, actualAuditGroup2);
        System.assertEquals(expectedParameters, actualParameters);
        System.assertEquals(actualParametersSerialized1, actualParametersSerialized2);
        System.assert(actualParametersSerialized1.contains(expectedSequenceName));
    }

}