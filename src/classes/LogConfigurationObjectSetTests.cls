@IsTest private class LogConfigurationObjectSetTests {

    static testmethod void canCorrectlySetStaticGroupIdentifierWhenDynamicGroupIdentifierEqNullDuringInsert() {
        //arrange
        List<LogConfiguration__c> logConfigurationsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfiguration__c
        ];
        Integer actualSizeBefore = logConfigurationsBefore.size();
        String staticIdentifier = 'STATIC';
        String dynamicIdentifier = null;
        
        //act
        insert new LogConfiguration__c(StaticGroupIdentifier__c = staticIdentifier);
        
        // assemble 
        List<LogConfiguration__c> logConfigurationsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfiguration__c
        ];
        Integer actualSizeAfter = logConfigurationsAfter.size();
        String actualDynamicGroupIdentifier;
        String actualStaticGroupIdentifier;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifier = logConfigurationsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifier = logConfigurationsAfter[0].StaticGroupIdentifier__c;
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
        
        LogConfigurationObjectSet.isEnabled = false;
        insert new LogConfiguration__c(
            StaticGroupIdentifier__c = staticIdentifier01, 
            DynamicGroupIdentifier__c = dynamicIdentifier01
        );
        
        List<LogConfiguration__c> logConfigurationsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfiguration__c
        ];
        Integer actualSizeBefore = logConfigurationsBefore.size();
        String actualDynamicGroupIdentifierBefore;
        String actualStaticGroupIdentifierBefore;
        if (actualSizeBefore == 1) {
            actualDynamicGroupIdentifierBefore = logConfigurationsBefore[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierBefore = logConfigurationsBefore[0].StaticGroupIdentifier__c;
        }
        
        //act
        LogConfigurationObjectSet.isEnabled = true;
        logConfigurationsBefore[0].StaticGroupIdentifier__c = staticIdentifier02;
        update logConfigurationsBefore[0];
        
        // assemble 
        List<LogConfiguration__c> logConfigurationsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfiguration__c
        ];
        Integer actualSizeAfter = logConfigurationsAfter.size();
        String actualDynamicGroupIdentifierAfter;
        String actualStaticGroupIdentifierAfter;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifierAfter = logConfigurationsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierAfter = logConfigurationsAfter[0].StaticGroupIdentifier__c;
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
        List<LogConfiguration__c> logConfigurationsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfiguration__c
        ];
        Integer actualSizeBefore = logConfigurationsBefore.size();
        String dynamicIdentifier = 'DYNAMIC';
        String staticIdentifier = null;
        
        //act
        insert new LogConfiguration__c(DynamicGroupIdentifier__c = dynamicIdentifier);
        
        // assemble 
        List<LogConfiguration__c> logConfigurationsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfiguration__c
        ];
        Integer actualSizeAfter = logConfigurationsAfter.size();
        String actualDynamicGroupIdentifier;
        String actualStaticGroupIdentifier;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifier = logConfigurationsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifier = logConfigurationsAfter[0].StaticGroupIdentifier__c;
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
        
        LogConfigurationObjectSet.isEnabled = false;
        insert new LogConfiguration__c(
            StaticGroupIdentifier__c = staticIdentifier01, 
            DynamicGroupIdentifier__c = dynamicIdentifier01
        );
        
        List<LogConfiguration__c> logConfigurationsBefore = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfiguration__c
        ];
        Integer actualSizeBefore = logConfigurationsBefore.size();
        String actualDynamicGroupIdentifierBefore;
        String actualStaticGroupIdentifierBefore;
        if (actualSizeBefore == 1) {
            actualDynamicGroupIdentifierBefore = logConfigurationsBefore[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierBefore = logConfigurationsBefore[0].StaticGroupIdentifier__c;
        }
        
        //act
        LogConfigurationObjectSet.isEnabled = true;
        logConfigurationsBefore[0].DynamicGroupIdentifier__c = dynamicIdentifier02;
        update logConfigurationsBefore[0];
        
        // assemble 
        List<LogConfiguration__c> logConfigurationsAfter = [
            SELECT Id, DynamicGroupIdentifier__c,  StaticGroupIdentifier__c
            FROM LogConfiguration__c
        ];
        Integer actualSizeAfter = logConfigurationsAfter.size();
        String actualDynamicGroupIdentifierAfter;
        String actualStaticGroupIdentifierAfter;
        if (actualSizeAfter == 1) {
            actualDynamicGroupIdentifierAfter = logConfigurationsAfter[0].DynamicGroupIdentifier__c;
            actualStaticGroupIdentifierAfter = logConfigurationsAfter[0].StaticGroupIdentifier__c;
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