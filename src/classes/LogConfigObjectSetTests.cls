@IsTest private class LogConfigObjectSetTests {

    static testmethod void canCorrectlySetStaticGroupIdentifierWhenDynamicGroupIdentifierEqNullDuringInsert() {
        //arrange
        List<LogConfig__c> logConfigsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfig__c
        ];
        Integer actualSizeBefore = logConfigsBefore.size();
        String staticIdentifier = 'STATIC';
        String dynamicIdentifier = null;
        
        //act
        insert new LogConfig__c(StaticGroupIdentifier__c = staticIdentifier);
        
        // assemble 
        List<LogConfig__c> logConfigsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfig__c
        ];
        Integer actualSizeAfter = logConfigsAfter.size();
        String actualDynamicGroupIdentifier;
        String actualStaticGroupIdentifier;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifier = logConfigsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifier = logConfigsAfter[0].StaticGroupIdentifier__c;
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
        
        LogConfigObjectSet.isEnabled = false;
        insert new LogConfig__c(
            StaticGroupIdentifier__c = staticIdentifier01, 
            DynamicGroupIdentifier__c = dynamicIdentifier01
        );
        
        List<LogConfig__c> logConfigsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfig__c
        ];
        Integer actualSizeBefore = logConfigsBefore.size();
        String actualDynamicGroupIdentifierBefore;
        String actualStaticGroupIdentifierBefore;
        if (actualSizeBefore == 1) {
            actualDynamicGroupIdentifierBefore = logConfigsBefore[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierBefore = logConfigsBefore[0].StaticGroupIdentifier__c;
        }
        
        //act
        LogConfigObjectSet.isEnabled = true;
        logConfigsBefore[0].StaticGroupIdentifier__c = staticIdentifier02;
        update logConfigsBefore[0];
        
        // assemble 
        List<LogConfig__c> logConfigsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfig__c
        ];
        Integer actualSizeAfter = logConfigsAfter.size();
        String actualDynamicGroupIdentifierAfter;
        String actualStaticGroupIdentifierAfter;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifierAfter = logConfigsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierAfter = logConfigsAfter[0].StaticGroupIdentifier__c;
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
        List<LogConfig__c> logConfigsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfig__c
        ];
        Integer actualSizeBefore = logConfigsBefore.size();
        String dynamicIdentifier = 'DYNAMIC';
        String staticIdentifier = null;
        
        //act
        insert new LogConfig__c(DynamicGroupIdentifier__c = dynamicIdentifier);
        
        // assemble 
        List<LogConfig__c> logConfigsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfig__c
        ];
        Integer actualSizeAfter = logConfigsAfter.size();
        String actualDynamicGroupIdentifier;
        String actualStaticGroupIdentifier;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifier = logConfigsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifier = logConfigsAfter[0].StaticGroupIdentifier__c;
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
        
        LogConfigObjectSet.isEnabled = false;
        insert new LogConfig__c(
            StaticGroupIdentifier__c = staticIdentifier01, 
            DynamicGroupIdentifier__c = dynamicIdentifier01
        );
        
        List<LogConfig__c> logConfigsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfig__c
        ];
        Integer actualSizeBefore = logConfigsBefore.size();
        String actualDynamicGroupIdentifierBefore;
        String actualStaticGroupIdentifierBefore;
        if (actualSizeBefore == 1) {
            actualDynamicGroupIdentifierBefore = logConfigsBefore[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierBefore = logConfigsBefore[0].StaticGroupIdentifier__c;
        }
        
        //act
        LogConfigObjectSet.isEnabled = true;
        logConfigsBefore[0].DynamicGroupIdentifier__c = dynamicIdentifier02;
        update logConfigsBefore[0];
        
        // assemble 
        List<LogConfig__c> logConfigsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfig__c
        ];
        Integer actualSizeAfter = logConfigsAfter.size();
        String actualDynamicGroupIdentifierAfter;
        String actualStaticGroupIdentifierAfter;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifierAfter = logConfigsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierAfter = logConfigsAfter[0].StaticGroupIdentifier__c;
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