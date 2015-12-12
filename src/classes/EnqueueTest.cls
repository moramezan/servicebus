@IsTest class EnqueueTest {
    
    //TODO needs more tests
    
    static testmethod void testToConfigIdsMissPreviousVersion() {
        //arrange prev version
        insert new Step__c(
            Name = '1#Test#1',
            IsDraft__c = false,
            Version__c = 1,
            Sequence__c = 'Test',
            Position__c = 1,
            ApexClassName__c = TerminateService.class.getName(),
            ConfigId__c = 'a01000000000001'
        );
        
        //arrange next version
        insert new Step__c(
            Name = '2#Test#1',
            IsDraft__c = false,
            Version__c = 2,
            Sequence__c = 'Test',
            Position__c = 1,
            ApexClassName__c = TerminateService.class.getName(),
            ConfigId__c = 'a01000000000002'
        );
        
        //arrange running version
        Application__c application = Application__c.getOrgDefaults();
        application.BrokerVersion__c = 2;
        upsert application;
        
        //act
        Test.startTest();
        System.enqueueJob(new Job(
            new Map<String,Object>{
                'ToConfigIds' => new Set<Id>{'a01000000000001', 'a01000000000002'}
            }
        ));
        Test.stopTest();
        
        //assemble
        Message__c message = [SELECT Id, Route__c FROM Message__c];
        
        //assert
        String expectedRoute = '2#Test#1';
        String actualRoute = message.Route__c;
        System.assertEquals(expectedRoute, actualRoute, 'Wrong route.');
    }
    
    static testmethod void testToConfigIdsHitsCurrentVersion() {
        //arrange live version
        insert new Step__c(
            Name = '1#Test#1',
            IsDraft__c = false,
            Version__c = 1,
            Sequence__c = 'Test',
            Position__c = 1,
            ApexClassName__c = TerminateService.class.getName(),
            ConfigId__c = 'a01000000000001'
        );
        
        //arrange draft version
        insert new Step__c(
            Name = '2#Test#1',
            IsDraft__c = true,
            Version__c = 2,
            Sequence__c = 'Test',
            Position__c = 1,
            ApexClassName__c = TerminateService.class.getName(),
            ConfigId__c = 'a01000000000002'
        );
        
        //arrange running version
        Application__c application = Application__c.getOrgDefaults();
        application.BrokerVersion__c = 1;
        upsert application;
        
        //act
        Test.startTest();
        System.enqueueJob(new Job(
            new Map<String,Object>{
                'ToConfigIds' => new Set<Id>{'a01000000000001', 'a01000000000002'}
            }
        ));
        Test.stopTest();
        
        //assemble
        Message__c message = [SELECT Id, Route__c FROM Message__c];
        
        //assert
        String expectedRoute = '1#Test#1';
        String actualRoute = message.Route__c;
        System.assertEquals(expectedRoute, actualRoute, 'Wrong route.');
    }
    
}