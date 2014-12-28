@IsTest  //-- no view of org data
private  class GateTest {
    
    static testmethod void hasTheCorrectLimits() {
        //arrange 
        Type actualType = Gate.class;
        Type outerClass = Type.forName(actualType.getName());  
        Type innerClass = Type.forName(outerClass.getName() + '.' + 'Meta'); 
        ProcessObject.Meta meta = (ProcessObject.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.Meta.class);
        
        //act 
        Integer actualLimits = meta.Limits;  

        //assemble
        actualLimits = (actualLimits == null) ? 1 : actualLimits; 

        //assert
        Integer expectedLimits = 1;
        System.assertEquals(expectedLimits, actualLimits);
    }


    static testmethod void callingExecuteReturnsExpectedParametersCollectionWhenGateItemsCountEqCount() {
        Gate.DeletionEnabled = false; //compensate for former uninserted GateSettings
        
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        Decimal count =  3 ;

        GateGroup__c gateGroup =  new GateGroup__c() ;
        insert gateGroup;
        Id gateGroupId = gateGroup.Id;

        Map<String,Object> parameters = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            '__Position' => position,
            'esb__GateGroupId' => gateGroupId,
            '__Count' => count,
            'data' => data
        };

        List<GateItem__c> gateItems = new List<GateItem__c> ();
        integer i = 1;
        while(i <= (count - 1)) // Adjust down by one (to allow the nth one inserted by execute() to equate with value in count)
        {
            Map<String,Object> n = parameters.clone();
            n.put('data' , 'x'+i);
            GateItem__c gateItem = new GateItem__c(
                GateGroup__c = gateGroupId,
                Parameters__c = json.serializePretty(n)
            );
            gateItems.add(gateItem);
            i++;
        }
        insert gateItems;

        Decimal expectedSize = 1;
        Id expectedGateGroupId = gateGroupId;
        Integer expectedGateItemsSize = (Integer) count;

        // Act
        Type reflector = Gate.class;
        List<Map<String,Object>> actualOutParametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        Id actualGateGroupId = null;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualGateGroupId = (Id) parameters.get('esb__Id' );
        }
        integer actualGateItemsSize = [SELECT COUNT() FROM GateItem__c];

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(actualGateGroupId , actualGateGroupId );
        System.assertEquals(expectedGateItemsSize , actualGateItemsSize );
    }
    
    
    static testmethod void callingExecuteReturnsExpectedParametersCollectionWhenGateItemsCountNotEqCount() {
        Gate.DeletionEnabled = false; //compensate for former uninserted GateSettings
        
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        Decimal count = 3 ;


        GateGroup__c gateGroup = new GateGroup__c() ;
        insert gateGroup;
        Id gateGroupId = gateGroup.Id;

        Map<String,Object> parameters = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            '__Position' => position,
            'esb__GateGroupId' => gateGroupId,
            '__Count' => count,
            'data' => data
        };

        List<GateItem__c> gateItems = new List<GateItem__c> ();
        integer i = 1;
        while(i <= (count - 2)) {// Adjust down by TWO ( one inserted by execute() will NOT  equate with value in count)
            Map<String,Object> n = parameters.clone();
            n.put('data' , 'x'+i);
            GateItem__c gateItem = new GateItem__c(
                GateGroup__c = gateGroupId ,
                Parameters__c = json.serializePretty(n)
            );
            gateItems.add(gateItem);
            i++;
        }
        insert gateItems;

        Decimal expectedSize = 0;
        Integer expectedGateItemsSize = (Integer) ( count - 1) ;

        // Act
        Type reflector = Gate.class;
        List<Map<String,Object>> actualOutParametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        Integer actualGateItemsSize = [SELECT COUNT() FROM GateItem__c];

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedGateItemsSize , actualGateItemsSize );
    }


    static testmethod void callingDeleteGateGroupsCorrectlyDeletesGateGroupsAndGateItemsWhenIsEnabledEqTrue() {
        // arrange 
        // Note this test is mocked as it's nearly impossible to modify the CreatedDate field 
        //      on a record - it's possible but json.deserialize() after injecting in the createddate 
        //      would take the implementation for the sake of testing
        //      to a very strange place!
        
        // arrange:
        String overThreshold = 'OVER'; // implies an "old" gate item record - conceptually older than "n" days
        Integer maximumItems = 5;      // the maximum number of gate item records 
        
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        GateGroup__c gateGroupD = new GateGroup__c();
        GateGroup__c gateGroupE = new GateGroup__c();
        GateGroup__c gateGroupF = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{   
            gateGroupA,
            gateGroupB,
            gateGroupC,
            gateGroupD,
            gateGroupE,
            gateGroupF
        };
        insert gateGroups;

        // inserted in "order"
        // gateItem01 is the oldest
        // gateItem12 is the newest
        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id, Parameters__c = overThreshold);
        insert gateItem01;
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupA.Id, Parameters__c = overThreshold);
        insert  gateItem02;
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupB.Id, Parameters__c = overThreshold);
        insert  gateItem03;
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem04;
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem05;
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem06;
        GateItem__c gateItem07 = new GateItem__c(GateGroup__c = gateGroupD.Id);
        insert  gateItem07;
        GateItem__c gateItem08 = new GateItem__c(GateGroup__c = gateGroupD.Id);
        insert  gateItem08;
        GateItem__c gateItem09 = new GateItem__c(GateGroup__c = gateGroupE.Id);
        insert  gateItem09;
        GateItem__c gateItem10 = new GateItem__c(GateGroup__c = gateGroupE.Id);
        insert  gateItem10;
        GateItem__c gateItem11 = new GateItem__c(GateGroup__c = gateGroupF.Id);
        insert  gateItem11;
        GateItem__c gateItem12 = new GateItem__c(GateGroup__c = gateGroupF.Id);
        insert  gateItem12;
        
        Gate.IGateItemProvider gateItemProviderTime = 
            new  Gate.MockGateItemProviderTime(overThreshold) ;
        Gate.IGateItemProvider gateItemProviderCount = 
            new Gate.GateItemProviderCount(maximumItems);

        Boolean isEnabled = true;

        
        // expectations :
        //  - gate items 01, 02, and 03 are "old" so they are removed
        //  - gate item 03 is part of gate group B which also has gate item 04
        //  - gate item 04 is therefore removed as well
        //  - that leaves gate items 05 thru 12, or a total of 8  gate items
        //  - the maximum allowable gate items is 5 - thus at least 3 gate items must be removed
        //  - using FIFO (first in first out) gate items 05, 06 and 07 are removed
        //  - gate item 07 is part of gate group D which also has gate item 08
        //  - gate item 08 is therefore removed as well
        //  - thus 4 gate items (09,10,11,12) and 2 gate groups(E,F) will survive

        // act:
        Gate.GateDeletionProvider gateDeletionProvider = 
            new Gate.GateDeletionProvider(isEnabled, gateItemProviderTime, gateItemProviderCount);
        gateDeletionProvider.deleteGateGroups();

        // assemble:
        List<GateGroup__c> gateGroupsAfter = [SELECT Id, Name FROM GateGroup__c];
        List<GateItem__c> gateItemsAfter = [SELECT Id, Name FROM GateItem__c];
        Integer actualGateGroupsAfterSize = gateGroupsAfter.size();
        Integer actualGateItemsAfterSize = gateItemsAfter.size();

        Boolean actualGateItemsFlag = true;  
        Set<Id> expectedGateItemIds = new Set<Id>{
            gateItem09.Id, gateItem10.Id, gateItem11.Id, gateItem12.Id
        };
        for (GateItem__c gateItem : gateItemsAfter) {
            if (!expectedGateItemIds.contains(gateItem.Id))
                actualGateItemsFlag = false; 
        }

        // assert:
        Integer expectedGateGroupsAfterSize = 2;
        System.assertEquals(expectedGateGroupsAfterSize,actualGateGroupsAfterSize);
        Integer expectedGateItemsAfterSize = 4;
        System.assertEquals(expectedGateItemsAfterSize,actualGateItemsAfterSize);
        Boolean expectedGateItemsFlag = true; 
        System.assertEquals(expectedGateItemsFlag,actualGateItemsFlag); 
    }


    static testmethod void callingDeleteGateGroupsPerformsNOOPWhenIsEnabledEqFalse() {
        // arrange:
        String overThreshold = 'OVER'; // implies an "old" gate item record - conceptually older than "n" days
        Integer maximumItems = 5;      // the maximum number of gate item records 

        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        GateGroup__c gateGroupD = new GateGroup__c();
        GateGroup__c gateGroupE = new GateGroup__c();
        GateGroup__c gateGroupF = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{   
        gateGroupA,
        gateGroupB,
        gateGroupC,
        gateGroupD,
        gateGroupE,
        gateGroupF
        };
        insert gateGroups;

        // inserted in "order"
        // gateItem01 is the oldest
        // gateItem12 is the newest
        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id, Parameters__c = overThreshold);
        insert gateItem01;
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupA.Id, Parameters__c = overThreshold);
        insert  gateItem02;
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupB.Id, Parameters__c = overThreshold);
        insert  gateItem03;
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem04;
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem05;
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem06;
        GateItem__c gateItem07 = new GateItem__c(GateGroup__c = gateGroupD.Id);
        insert  gateItem07;
        GateItem__c gateItem08 = new GateItem__c(GateGroup__c = gateGroupD.Id);
        insert  gateItem08;
        GateItem__c gateItem09 = new GateItem__c(GateGroup__c = gateGroupE.Id);
        insert  gateItem09;
        GateItem__c gateItem10 = new GateItem__c(GateGroup__c = gateGroupE.Id);
        insert  gateItem10;
        GateItem__c gateItem11 = new GateItem__c(GateGroup__c = gateGroupF.Id);
        insert  gateItem11;
        GateItem__c gateItem12 = new GateItem__c(GateGroup__c = gateGroupF.Id);
        insert  gateItem12;
        
        Gate.IGateItemProvider gateItemProviderTime = 
            new Gate.MockGateItemProviderTime(overThreshold);
        Gate.IGateItemProvider gateItemProviderCount = 
            new Gate.GateItemProviderCount(maximumItems);
        
        Boolean isEnabled = false;
        
        // expectations :
        //  - NOOP
        //  - thus 12 gate items (01 - 12) and 6 gate groups(A - F) will survive

        // act:
        Gate.GateDeletionProvider gateDeletionProvider = 
            new Gate.GateDeletionProvider(isEnabled, gateItemProviderTime, gateItemProviderCount);
        gateDeletionProvider.deleteGateGroups();

        // assemble:
        List<GateGroup__c> gateGroupsAfter = [SELECT Id, Name FROM GateGroup__c];
        List<GateItem__c> gateItemsAfter = [SELECT Id, Name FROM GateItem__c];
        Integer actualGateGroupsAfterSize = gateGroupsAfter.size();
        Integer actualGateItemsAfterSize = gateItemsAfter.size();

        // assert:
        Integer expectedGateGroupsAfterSize = 6;
        System.assertEquals(expectedGateGroupsAfterSize,actualGateGroupsAfterSize);
        Integer expectedGateItemsAfterSize = 12;
        System.assertEquals(expectedGateItemsAfterSize,actualGateItemsAfterSize);
    }

   
    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds() {
        // arrange:
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c> {
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        List<GateItem__c> gateItems = new List<GateItem__c>{
            gateItem01,
            gateItem03,
            gateItem04,
            gateItem06      
        };
        insert gateItems;

        // act:
        Set<Id> actualGateGroupIds = Gate.getGateGroupIds(gateItems);
        
        // assert:
        Set<Id> expectedGateGroupIds = new Set<Id>{gateGroupA.Id, gateGroupC.Id};
        System.assertEquals(expectedGateGroupIds, actualGateGroupIds);
    }


    static testmethod void callingGetGateItemsOverDateThresholdMockReturnsExpectedGateItems() {
        // arrange:
        String overThreshold = 'OVER';

        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id, Parameters__c = null);
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupB.Id, Parameters__c = overThreshold);
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupC.Id, Parameters__c = null);
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupA.Id, Parameters__c = null);
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupB.Id, Parameters__c = overThreshold);
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id, Parameters__c = null);
        List<GateItem__c> gateItems = new List<GateItem__c> {
            gateItem01,
            gateItem02,
            gateItem03,
            gateItem04,
            gateItem05,
            gateItem06      
        };
        insert gateItems;

        // act:
        List<GateItem__c> actualGateItems =  Gate.getGateItemsOverDateThresholdMock(overThreshold);

        // assemble
        Set<Id> actualGateItemIds = (new Map<Id, GateItem__c>(actualGateItems)).keySet();

        // assert:
        Set<Id> expectedGateItemIds = new Set<Id>{gateItem02.Id, gateItem05.Id};
        System.assertEquals(expectedGateItemIds, actualGateItemIds);
    }  

   
    static testmethod void callingGetCountThresholdReturnsExpectedCountThreshold() {
        // arrange:
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        List<GateItem__c> gateItems = new List<GateItem__c> {
            gateItem01,
            gateItem02,
            gateItem03,
            gateItem04,
            gateItem05,
            gateItem06      
        };
        insert gateItems;

        Integer delta = 2;
        Integer maximumItems = gateItems.size() - delta;
        
        // act:
        Integer actualCountThreshold = Gate.getCountThreshold(maximumItems);

        // assert:
        Integer expectedCountThreshold = delta;
        System.assertEquals(expectedCountThreshold, actualCountThreshold);
    }


    static testmethod void callingGetDateThresholdReturnsDateTimeEarlierThanNow() {
        // arrange:
        DateTime now = System.now() ;
        Integer maximumDays  =  30;

        // act:
        DateTime actualDateThreshold = Gate.getDateThreshold(now, maximumDays);

        // assert
        System.assert(now > actualDateThreshold);
    }

 
    static testmethod void callingGetGateItemsOverCountThresholdReturnsExpectedGateItems() {
        // arrange:
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        insert gateItem01;
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem02;
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem03;
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        insert  gateItem04;
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem05;
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem06;

        Integer maximumItems = 4;
        Integer countThreshold = Gate.getCountThreshold(maximumItems);

        // act:
        List<GateItem__c> actualGateItemsOverCountThreshold = Gate.getGateItemsOverCountThreshold(countThreshold);

        // assemble:
        Integer actualSize = actualGateItemsOverCountThreshold.size();
        Set<Id> actualGateItemIds = (new Map<Id,GateItem__c >(actualGateItemsOverCountThreshold)).keySet();

        // assert:
        Integer expectedSize = 6 - maximumItems;
        System.assertEquals(expectedSize, actualSize);
        Set<Id> expectedGateItemIds = new Set<Id>{
            gateItem01.Id, gateItem02.Id
        };
        System.assertEquals(expectedGateItemIds, actualGateItemIds);     
    }

  
    static testmethod void callingGetGateItemsOverDateThresholdImplReturnsExpectedGateItems() {
        // arrange:
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        List<GateItem__c> gateItems = new List<GateItem__c>{
            gateItem01,
            gateItem02,
            gateItem03,
            gateItem04,
            gateItem05,
            gateItem06      
        };
        insert gateItems;

        Integer arbitarySmallOffsetInPast = 2 * -1;
        DateTime dateThreshold = system.now().addDays(arbitarySmallOffsetInPast);

        // act:
        List<GateItem__c> actualGateItems  =  Gate.getGateItemsOverDateThresholdImpl(dateThreshold);
        
        // assemble:
        Integer actualSize = actualGateItems.size();

        // assert:
        Integer expectedSize = gateItems.size();
        System.assertEquals(expectedSize, actualSize);
    }


    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds01() {
        // arrange:
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        insert gateItem01;
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        insert  gateItem02;
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem03;
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem04;
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem05;
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem06;

        Integer maximumItems = 4;

        // act:
        Gate.IGateItemProvider gateItemProvider = new GAte.GateItemProviderCount(maximumItems);
        Set<Id> actualGateGroupIds = gateItemProvider.getGateGroupIds();

        // assemble:
        Integer actualSize = actualGateGroupIds.size();

        // assert:
        Integer expectedSize = 1;
        System.assertEquals(expectedSize,actualSize );
        Set<Id> expectedGateGroupIds = new Set<Id>{gateGroupA.Id};
        System.assertEquals(expectedGateGroupIds,actualGateGroupIds);
    }


    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds02() {
        // arrange:
        String overThreshold = 'OVER';
        
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id, Parameters__c = overThreshold);
        insert gateItem01;
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupA.Id, Parameters__c = overThreshold);
        insert  gateItem02;
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem03;
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem04;
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem05;
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem06;

        // act:
        Gate.IGateItemProvider gateItemProvider = new Gate.MockGateItemProviderTime(overThreshold);
        Set<Id> actualGateGroupIds = gateItemProvider.getGateGroupIds();

        // assemble:
        Integer actualSize = actualGateGroupIds.size();

        // assert:
        Integer expectedSize = 1;
        System.assertEquals(expectedSize,actualSize );
        Set<Id> expectedGateGroupIds = new Set<Id>{gateGroupA.Id};
        System.assertEquals(expectedGateGroupIds,actualGateGroupIds);
    }


    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds03A() {
        // arrange:
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        insert gateItem01;
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        insert  gateItem02;
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem03;
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem04;
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem05;
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem06;

        Integer arbitarySMALLOffsetIntoFuture = 2;
        DateTime X = system.now().addDays(arbitarySMALLOffsetIntoFuture);
        Integer maximumDays = 30;

        //  <---too old---||---- acceptable ----| true now |------"future" --------- >
        //  X = "now" + arbitarySMALLOffsetIntoFuture
        //  <---too old---||---- acceptable ----| true now |-- X ----"future" ------- >

        // act:
        Gate.IGateItemProvider gateItemProvider = new Gate.GateItemProviderTime(X, maximumDays);
        Set<Id> actualGateGroupIds = gateItemProvider.getGateGroupIds();

        // assemble:
        Integer actualSize = actualGateGroupIds.size();

        // assert:
        Integer expectedSize = 3;
        System.assertEquals(expectedSize,actualSize );
    }


    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds03B() {
        // arrange:
        GateGroup__c gateGroupA = new GateGroup__c();
        GateGroup__c gateGroupB = new GateGroup__c();
        GateGroup__c gateGroupC = new GateGroup__c();
        List<GateGroup__c> gateGroups = new List<GateGroup__c>{
            gateGroupA,
            gateGroupB,
            gateGroupC
        };
        insert gateGroups;

        GateItem__c gateItem01 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        insert gateItem01;
        GateItem__c gateItem02 = new GateItem__c(GateGroup__c = gateGroupA.Id);
        insert  gateItem02;
        GateItem__c gateItem03 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem03;
        GateItem__c gateItem04 = new GateItem__c(GateGroup__c = gateGroupB.Id);
        insert  gateItem04;
        GateItem__c gateItem05 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem05;
        GateItem__c gateItem06 = new GateItem__c(GateGroup__c = gateGroupC.Id);
        insert  gateItem06;

        Integer arbitaryOffset  = 2;
        Integer maximumDays = 30;
        Integer arbitaryLARGEOffsetIntoFuture = maximumDays + arbitaryOffset;
        DateTime X = system.now().addDays(arbitaryLARGEOffsetIntoFuture);

        //  <---too old---||---- acceptable ----| true now |------"future" --------- >
        //  X = "true now" + arbitaryLARGEOffsetIntoFuture
        //  <---too old---||---- acceptable ----| true now |------"future" --------- X --------- >

        // act:
        Gate.IGateItemProvider gateItemProvider = new Gate.GateItemProviderTime(X, maximumDays);
        Set<Id> actualGateGroupIds = gateItemProvider.getGateGroupIds();

        // assemble:
        Integer actualSize = actualGateGroupIds.size();

        // assert:
        Integer expectedSize = 0;
        System.assertEquals(expectedSize,actualSize );
    }
}