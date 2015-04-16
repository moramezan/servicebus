@IsTest private class AuditInitializerConfigSetModelTest {

    static testmethod void canCorrectlySetStaticGroupIdentifierWhenDynamicGroupIdentifierEqNullDuringInsert() {
        //arrange
        List<AuditInitializerConfig__c> auditInitializerConfigsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        Integer actualSizeBefore = auditInitializerConfigsBefore.size();
        String staticIdentifier = 'STATIC';
        String dynamicIdentifier = null;
        
        //act
        insert new AuditInitializerConfig__c(StaticGroupIdentifier__c = staticIdentifier);
        
        // assemble
        List<AuditInitializerConfig__c> auditInitializerConfigsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        Integer actualSizeAfter = auditInitializerConfigsAfter.size();
        String actualDynamicGroupIdentifier;
        String actualStaticGroupIdentifier;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifier = auditInitializerConfigsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifier = auditInitializerConfigsAfter[0].StaticGroupIdentifier__c;
        }
        
        //assert
        Integer expectedSizeBefore = 0;
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        Integer expectedSizeAfter = 1;
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        String expectedDynamicGroupIdentifier = dynamicIdentifier;
        System.assertEquals(expectedDynamicGroupIdentifier, actualDynamicGroupIdentifier);
        String expectedStaticGroupIdentifier = staticIdentifier;
        System.assertEquals(expectedStaticGroupIdentifier, actualStaticGroupIdentifier);
    }


    static testmethod void canCorrectlySetStaticGroupIdentifierWhenDynamicGroupIdentifierNotEqNullWithUpdate() {
        //arrange
        String staticIdentifier01 = null;
        String dynamicIdentifier01 = 'DYNAMIC-STEP-01';
        String staticIdentifier02 = 'STATIC-STEP-02';
        String dynamicIdentifier02 = null;
        
        AuditInitializerConfigSetModel.isEnabled = false;
        insert new AuditInitializerConfig__c(
            StaticGroupIdentifier__c = staticIdentifier01,
            DynamicGroupIdentifier__c = dynamicIdentifier01
        );
        
        List<AuditInitializerConfig__c> auditInitializerConfigsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        Integer actualSizeBefore = auditInitializerConfigsBefore.size();
        String actualDynamicGroupIdentifierBefore;
        String actualStaticGroupIdentifierBefore;
        if (actualSizeBefore == 1) {
            actualDynamicGroupIdentifierBefore = auditInitializerConfigsBefore[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierBefore = auditInitializerConfigsBefore[0].StaticGroupIdentifier__c;
        }
        
        //act
        AuditInitializerConfigSetModel.isEnabled = true;
        auditInitializerConfigsBefore[0].StaticGroupIdentifier__c = staticIdentifier02;
        update auditInitializerConfigsBefore[0];
        
        // assemble
        List<AuditInitializerConfig__c> auditInitializerConfigsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        Integer actualSizeAfter = auditInitializerConfigsAfter.size();
        String actualDynamicGroupIdentifierAfter;
        String actualStaticGroupIdentifierAfter;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifierAfter = auditInitializerConfigsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierAfter = auditInitializerConfigsAfter[0].StaticGroupIdentifier__c;
        }
        
        //assert
        Integer expectedSizeBefore = 1;
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        String expectedDynamicGroupIdentifierBefore = dynamicIdentifier01;
        System.assertEquals(expectedDynamicGroupIdentifierBefore, actualDynamicGroupIdentifierBefore);
        String expectedStaticGroupIdentifierBefore = staticIdentifier01;
        System.assertEquals(expectedStaticGroupIdentifierBefore, actualStaticGroupIdentifierBefore);
        
        Integer expectedSizeAfter = 1;
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        String expectedDynamicGroupIdentifierAfter = dynamicIdentifier02;
        System.assertEquals(expectedDynamicGroupIdentifierAfter, actualDynamicGroupIdentifierAfter);
        String expectedStaticGroupIdentifierAfter = staticIdentifier02;
        System.assertEquals(expectedStaticGroupIdentifierAfter, actualStaticGroupIdentifierAfter);
    }


    static testmethod void canCorrectlySetDynamicGroupIdentifierWhenStaticGroupIdentifierEqNullDuringInsert() {
        //arrange
        List<AuditInitializerConfig__c> auditInitializerConfigsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        Integer actualSizeBefore = auditInitializerConfigsBefore.size();
        String dynamicIdentifier = 'DYNAMIC';
        String staticIdentifier = null;
        
        //act
        insert new AuditInitializerConfig__c(DynamicGroupIdentifier__c = dynamicIdentifier);
        
        // assemble
        List<AuditInitializerConfig__c> auditInitializerConfigsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        Integer actualSizeAfter = auditInitializerConfigsAfter.size();
        String actualDynamicGroupIdentifier;
        String actualStaticGroupIdentifier;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifier = auditInitializerConfigsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifier = auditInitializerConfigsAfter[0].StaticGroupIdentifier__c;
        }
        
        //assert
        Integer expectedSizeBefore = 0;
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        Integer expectedSizeAfter = 1;
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        String expectedStaticGroupIdentifier = staticIdentifier;
        System.assertEquals(expectedStaticGroupIdentifier, actualStaticGroupIdentifier);
        String expectedDynamicGroupIdentifier = dynamicIdentifier;
        System.assertEquals(expectedDynamicGroupIdentifier, actualDynamicGroupIdentifier);
    }


    static testmethod void canCorrectlySetDynamicGroupIdentifierWhenStaticGroupIdentifierNotEqNullWithUpdate() {
        //arrange
        String staticIdentifier01 = 'STATIC-STEP-01';
        String dynamicIdentifier01 = null;
        String staticIdentifier02 =  null;
        String dynamicIdentifier02 = 'DYNAMIC-STEP-02';
        
        AuditInitializerConfigSetModel.isEnabled = false;
        insert new AuditInitializerConfig__c(
            StaticGroupIdentifier__c = staticIdentifier01,
            DynamicGroupIdentifier__c = dynamicIdentifier01
        );
        
        List<AuditInitializerConfig__c> auditInitializerConfigsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        Integer actualSizeBefore = auditInitializerConfigsBefore.size();
        String actualDynamicGroupIdentifierBefore;
        String actualStaticGroupIdentifierBefore;
        if (actualSizeBefore == 1) {
            actualDynamicGroupIdentifierBefore = auditInitializerConfigsBefore[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierBefore = auditInitializerConfigsBefore[0].StaticGroupIdentifier__c;
        }
        
        //act
        AuditInitializerConfigSetModel.isEnabled = true;
        auditInitializerConfigsBefore[0].DynamicGroupIdentifier__c = dynamicIdentifier02;
        update auditInitializerConfigsBefore[0];
        
        // assemble
        List<AuditInitializerConfig__c> auditInitializerConfigsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM AuditInitializerConfig__c
        ];
        Integer actualSizeAfter = auditInitializerConfigsAfter.size();
        String actualDynamicGroupIdentifierAfter;
        String actualStaticGroupIdentifierAfter;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifierAfter = auditInitializerConfigsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierAfter = auditInitializerConfigsAfter[0].StaticGroupIdentifier__c;
        }
        
        //assert
        Integer expectedSizeBefore = 1;
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        String expectedDynamicGroupIdentifierBefore = dynamicIdentifier01;
        System.assertEquals(expectedDynamicGroupIdentifierBefore, actualDynamicGroupIdentifierBefore);
        String expectedStaticGroupIdentifierBefore = staticIdentifier01;
        System.assertEquals(expectedStaticGroupIdentifierBefore, actualStaticGroupIdentifierBefore);
        
        Integer expectedSizeAfter = 1;
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        String expectedDynamicGroupIdentifierAfter = dynamicIdentifier02;
        System.assertEquals(expectedDynamicGroupIdentifierAfter, actualDynamicGroupIdentifierAfter);
        String expectedStaticGroupIdentifierAfter = staticIdentifier02;
        System.assertEquals(expectedStaticGroupIdentifierAfter, actualStaticGroupIdentifierAfter);
    }
}