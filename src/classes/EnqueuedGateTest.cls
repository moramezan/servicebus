@IsTest public class EnqueuedGateTest {

    static testmethod void callingInvokeMainReturnsZeroOutputEventsWhenMessagesWithZeroHopsNotEqGateItemsCount() {
        // Arrange
        Decimal count =  3 ;
        Decimal insertIntoMessageCount = count;
        Decimal insertIntoGateItemCount = count - 1;  // Adjust down by one
                                                      // expect: the insertion of additional GateItem under "Act"

        String queueableId = '1234567';

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__Hops' => 2,  // Only Hops value of "1" will be counted towards the triggering release total
            '__QueueableId' => queueableId
        };

        List<EnqueuedGateItem__c> EnqueuedGateItems = new List<EnqueuedGateItem__c> ();
        List<Message__c> messages = new List<Message__c> ();
        integer i = 1;
        while(i <= count) {
            Map<String,Object> event = inputEvent.clone();
            event.put('c__data' , 'x'+i);
            EnqueuedGateItem__c EnqueuedGateItem = new EnqueuedGateItem__c(
                GateGroup__c = queueableId,
                Event__c = json.serialize(event)
            );
            if (i <= insertIntoGateItemCount) {
                EnqueuedGateItems.add(EnqueuedGateItem);
            }
            if (i <= insertIntoMessageCount) {
                messages.add(new Message__c(Event__c = json.serialize(event)));
            }
            i++;
        }
        insert EnqueuedGateItems;
        insert messages;

        // Act
        EnqueuedGate.DeletionEnabled = false;
        Type reflector = EnqueuedGate.class;
        List<Map<String,Object>> actualOutputEvents = new Broker.Wrapper(reflector, inputEvent, null).invokeMain().Outputs;

        // Assemble
        Decimal actualSize = actualOutputEvents.size();
        Integer actualEnqueuedGateItemsSize = [SELECT COUNT() FROM EnqueuedGateItem__c];

        // Assert
        Decimal expectedSize = 0;
        System.assertEquals(expectedSize , actualSize);
        Integer expectedEnqueuedGateItemsSize = (Integer)insertIntoGateItemCount + 1;
        System.assertEquals(expectedEnqueuedGateItemsSize , actualEnqueuedGateItemsSize );

        ////  // Assemble
        ////  Map<String,Object> actualOutputEvent = actualOutputEvents[0];
        ////  String actualqueueableId = (String)inputEvent.get('__QueueableId' );
        ////
        ////  // Assert
        ////  String expectedqueueableId = queueableId;
        ////  System.assertEquals(expectedqueueableId , actualqueueableId );
    }
    static testmethod void callingInvokeMainThrowsExpectedExceptionWhenqueueableIdIsNull() {
          // Arrange
         Map<String,Object> inputEvent = new Map<String,Object> {
            '__Hops' => 1
            //'__QueueableId' => '12345' // null __QueueableId so expect error
        };

        // Act
        Boolean actualFlag = false;
        try {
            EnqueuedGate.DeletionEnabled = false;
            Type reflector = EnqueuedGate.class;
            List<Map<String,Object>> actualOutputEvents = new Broker.Wrapper(reflector, inputEvent, null).invokeMain().Outputs;

        } catch (Exception e) {
            actualFlag = e.getMessage().contains('missing mandatory __QueueableId');
        }

        // Assert
        Boolean exoectedFlag = true;
        System.assertEquals(exoectedFlag , actualFlag);
    }
    static testmethod void callingInvokeMainThrowsExpectedExceptionWhenHopsIsNull() {
          // Arrange
         Map<String,Object> inputEvent = new Map<String,Object> {
            // '__Hops' => 1, // null __Hops so expect error
            '__QueueableId' => '12345'
        };

        // Act
        Boolean actualFlag = false;
        try {
            EnqueuedGate.DeletionEnabled = false;
            Type reflector = EnqueuedGate.class;
            List<Map<String,Object>> actualOutputEvents = new Broker.Wrapper(reflector, inputEvent, null).invokeMain().Outputs;

        } catch (Exception e) {
            actualFlag = e.getMessage().contains('missing mandatory __Hops');
        }

        // Assert
        Boolean exoectedFlag = true;
        System.assertEquals(exoectedFlag , actualFlag);
    }


    static testmethod void callingInvokeMainReturnsExpectedOutputEventsWhenEnqueuedGateItemsCountEqCount() {
        // Arrange
        Decimal count =  3 ;
        Decimal insertIntoMessageCount = count;
        Decimal insertIntoGateItemCount = count - 1;  // Adjust down by one
                                                      // expect: the insertion of additional GateItem under "Act"
                                                      // WILL trigger release

        String queueableId = '1234567';

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__Hops' => 1,
            '__QueueableId' => queueableId
        };

        List<EnqueuedGateItem__c> EnqueuedGateItems = new List<EnqueuedGateItem__c> ();
        List<Message__c> messages = new List<Message__c> ();
        integer i = 1;
        while(i <= count) {
            Map<String,Object> event = inputEvent.clone();
            event.put('c__data' , 'x'+i);
            EnqueuedGateItem__c EnqueuedGateItem = new EnqueuedGateItem__c(
                GateGroup__c = queueableId,
                Event__c = json.serialize(event)
            );
            if (i <= insertIntoGateItemCount) {
                EnqueuedGateItems.add(EnqueuedGateItem);
            }
            if (i <= insertIntoMessageCount) {
                messages.add(new Message__c(Event__c = json.serialize(event)));
            }
            i++;
        }
        insert EnqueuedGateItems;
        insert messages;

        // Act
        EnqueuedGate.DeletionEnabled = false;
        Type reflector = EnqueuedGate.class;
        List<Map<String,Object>> actualOutputEvents = new Broker.Wrapper(reflector, inputEvent, null).invokeMain().Outputs;

        // Assemble
        Decimal actualSize = actualOutputEvents.size();
        Integer actualEnqueuedGateItemsSize = [SELECT COUNT() FROM EnqueuedGateItem__c];

        // Assert
        Decimal expectedSize = 1;
        System.assertEquals(expectedSize , actualSize);
        Integer expectedEnqueuedGateItemsSize = (Integer)insertIntoGateItemCount + 1;
        System.assertEquals(expectedEnqueuedGateItemsSize , actualEnqueuedGateItemsSize );

        // Assemble
        Map<String,Object> actualOutputEvent = actualOutputEvents[0];
        String actualqueueableId = (String)inputEvent.get('__QueueableId' );

        // Assert
        String expectedqueueableId = queueableId;
        System.assertEquals(expectedqueueableId , actualqueueableId );
    }


    static testmethod void callingInvokeMainReturnsExpectedOutputEventsWhenEnqueuedGateItemsCountNotEqCount() {
        // Arrange
        Decimal count =  3 ;
        Decimal insertIntoMessageCount = count;
        Decimal insertIntoGateItemCount = count - 1 - 1;  // Adjust down by two
                                                          // expect: the insertion of additional GateItem under
                                                          // "Act" WILL NOT trigger release

        String queueableId = '1234567';

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__Hops' => 1,
            '__QueueableId' => queueableId
        };

        List<EnqueuedGateItem__c> EnqueuedGateItems = new List<EnqueuedGateItem__c> ();
        List<Message__c> messages = new List<Message__c> ();
        integer i = 1;
        while(i <= count) {
            Map<String,Object> event = inputEvent.clone();
            event.put('c__data' , 'x'+i);
            EnqueuedGateItem__c EnqueuedGateItem = new EnqueuedGateItem__c(
                GateGroup__c = queueableId,
                Event__c = json.serialize(event)
            );
            if (i <= insertIntoGateItemCount) {
                EnqueuedGateItems.add(EnqueuedGateItem);
            }
            if (i <= insertIntoMessageCount) {
                messages.add(new Message__c(Event__c = json.serialize(event)));
            }
            i++;
        }
        insert EnqueuedGateItems;
        insert messages;

        // Act
        EnqueuedGate.DeletionEnabled = false;
        Type reflector = EnqueuedGate.class;
        List<Map<String,Object>> actualOutputEvents = new Broker.Wrapper(reflector, inputEvent, null).invokeMain().Outputs;

        // Assemble
        Decimal actualSize = actualOutputEvents.size();
        Integer actualEnqueuedGateItemsSize = [SELECT COUNT() FROM EnqueuedGateItem__c];

        // Assert
        Decimal expectedSize = 0; // No release
        System.assertEquals(expectedSize , actualSize);
        Integer expectedEnqueuedGateItemsSize = (Integer)insertIntoGateItemCount + 1;
        System.assertEquals(expectedEnqueuedGateItemsSize , actualEnqueuedGateItemsSize );
    }

    static testmethod void callingGetCommonParametersReturnsExpectedCollection01() {
        // Arrange :
        List<EnqueuedGateItem__c> gateItems = new List<EnqueuedGateItem__c>{
            new EnqueuedGateItem__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => 'v1',
                        'p2' => 'v2'
                    }
                )
            ),
            new EnqueuedGateItem__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => 'v1',
                        'p2' => 'v2'
                    }
                )
            )
        };

        // Act
        Map<String,Object> actualCommonParameters = EnqueuedGate.getCommonParameters(gateItems);

        // prepare
        Decimal actualSize = actualCommonParameters.keySet().size();


        // Assert
        Integer expectedSize = 2;
        System.assertEquals(expectedSize , actualSize );
    }


    static testmethod void callingGetCommonParametersReturnsExpectedCollection02() {
        // Arrange :
        List<EnqueuedGateItem__c> gateItems = new List<EnqueuedGateItem__c>{
            new EnqueuedGateItem__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => 'v1',
                        'p2' => 'v2',
                        'p3' => 'v3'   // not present on all
                    }
                )
            ),
            new EnqueuedGateItem__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => 'v1',
                        'p2' => 'v2'
                    }
                )
            )
        };

        // Act
        Map<String,Object> actualCommonParameters = EnqueuedGate.getCommonParameters(gateItems);

        // prepare
        Decimal actualSize = actualCommonParameters.keySet().size();
        Boolean actual01 = actualCommonParameters.keySet().contains('p1');
        Boolean actual02 = actualCommonParameters.keySet().contains('p2');
        Boolean actual03 = actualCommonParameters.keySet().contains('p3');

        // Assert
        Integer expectedSize = 2;
        System.assertEquals(expectedSize , actualSize);
        Boolean expected01 = true;
        System.assertEquals(expected01 , actual01);
        Boolean expected02 = true;
        System.assertEquals(expected02 , actual02);
        Boolean expected03 = false;
        System.assertEquals(expected03 , actual03);
    }

    static testmethod void callingGetCommonParametersReturnsExpectedCollection03() {
        // Arrange :
        List<EnqueuedGateItem__c> gateItems = new List<EnqueuedGateItem__c>{
            new EnqueuedGateItem__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => null,  // present on all, but null
                        'p2' => 'v2',
                        'p3' => 'v3'   // not present on all
                    }
                )
            ),
            new EnqueuedGateItem__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => null, // present on all, but null
                        'p2' => 'v2'
                    }
                )
            )
        };

        // Act
        Map<String,Object> actualCommonParameters = EnqueuedGate.getCommonParameters(gateItems);

        // prepare
        Decimal actualSize = actualCommonParameters.keySet().size();
        Boolean actual01 = actualCommonParameters.keySet().contains('p1');
        Boolean actual02 = actualCommonParameters.keySet().contains('p2');
        Boolean actual03 = actualCommonParameters.keySet().contains('p3');

        // Assert
        Integer expectedSize = 1;
        System.assertEquals(expectedSize , actualSize);
        Boolean expected01 = false;
        System.assertEquals(expected01 , actual01);
        Boolean expected02 = true;
        System.assertEquals(expected02 , actual02);
        Boolean expected03 = false;
        System.assertEquals(expected03 , actual03);
    }

    static testmethod void callingCleanParametersReturnsExpectedCollection() {
        // Arrange :
        Map<String,Object> parameters = new Map<String,Object> {
            '__x' => 'v1',
            'esb__x' => 'v2',
            'balls' => 'v3'
        };

        // Act
        Map<String,Object> actualParameters =  EnqueuedGate.cleanParameters(parameters);


        // prepare
        Boolean actual01 = (actualParameters.get('__x') != null);
        Boolean actual02 = (actualParameters.get('esb__x') != null);
        Boolean actual03 = (actualParameters.get('balls') == null);

        // Assert
        Boolean expected01 = true;
        System.assertEquals(expected01 , actual01);
        Boolean expected02 = true;
        System.assertEquals(expected02 , actual02);
        Boolean expected03 = true;
        System.assertEquals(expected03 , actual03);
    }

    static testmethod void callingsStripDoubleUnderScoreReturnsExpectedCollection() {
        // Arrange :
        Map<String,Object> parameters = new Map<String,Object> {
            '__x' => 'v1',
            'esb__x' => 'v2',
            'balls' => 'v3'
        };

        // Act
        Map<String,Object> actualParameters =  EnqueuedGate.stripDoubleUnderScore(parameters);


        // prepare
        Boolean actual01 = (actualParameters.get('__x') == null);
        Boolean actual02 = (actualParameters.get('esb__x') != null);
        Boolean actual03 = (actualParameters.get('balls') != null);

        // Assert
        Boolean expected01 = true;
        System.assertEquals(expected01 , actual01);
        Boolean expected02 = true;
        System.assertEquals(expected02 , actual02);
        Boolean expected03 = true;
        System.assertEquals(expected03 , actual03);
    }


// DELETION STRATEGY TESTS:
    static testmethod void callingDeleteGateGroupsCorrectlyDeletesGateGroupsAndGateItemsWhenIsEnabledEqTrue() {
        // arrange
        // Note this test is mocked as it's nearly impossible to modify the CreatedDate field
        //      on a record - it's possible but json.deserialize() after injecting in the createddate
        //      would take the implementation for the sake of testing
        //      to a very strange place!

        // arrange:
        String overThreshold = 'OVER'; // implies an "old" gate item record - conceptually older than "n" days
        Integer maximumItems = 5;      // the maximum number of gate item records

        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';
        String gateGroupDQueueableId = 'D1234567';
        String gateGroupEQueueableId = 'E1234567';
        String gateGroupFQueueableId = 'F1234567';


        // inserted in "order"
        // gateItem01 is the oldest
        // gateItem12 is the newest
        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId, Event__c = overThreshold);
        insert gateItem01;
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId, Event__c = overThreshold);
        insert  gateItem02;
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId, Event__c = overThreshold);
        insert  gateItem03;
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem04;
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem05;
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem06;
        EnqueuedGateItem__c gateItem07 = new EnqueuedGateItem__c(GateGroup__c = gateGroupDQueueableId);
        insert  gateItem07;
        EnqueuedGateItem__c gateItem08 = new EnqueuedGateItem__c(GateGroup__c = gateGroupDQueueableId);
        insert  gateItem08;
        EnqueuedGateItem__c gateItem09 = new EnqueuedGateItem__c(GateGroup__c = gateGroupEQueueableId);
        insert  gateItem09;
        EnqueuedGateItem__c gateItem10 = new EnqueuedGateItem__c(GateGroup__c = gateGroupEQueueableId);
        insert  gateItem10;
        EnqueuedGateItem__c gateItem11 = new EnqueuedGateItem__c(GateGroup__c = gateGroupFQueueableId);
        insert  gateItem11;
        EnqueuedGateItem__c gateItem12 = new EnqueuedGateItem__c(GateGroup__c = gateGroupFQueueableId);
        insert  gateItem12;

        EnqueuedGate.IEnqueuedGateItemProvider EnqueuedGateItemProviderTime =
            new  EnqueuedGate.MockEnqueuedGateItemProviderTime(overThreshold) ;
        EnqueuedGate.IEnqueuedGateItemProvider EnqueuedGateItemProviderCount =
            new EnqueuedGate.EnqueuedGateItemProviderCount(maximumItems);

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
        EnqueuedGate.EnqueuedGateDeletionProvider gateDeletionProvider =
            new EnqueuedGate.EnqueuedGateDeletionProvider(isEnabled, EnqueuedGateItemProviderTime, EnqueuedGateItemProviderCount);
        gateDeletionProvider.deleteEnqueuedGateGroups();

        // assemble:
        List<String> gateGroupsAfter = new List<String>{
            gateGroupAQueueableId,
            gateGroupBQueueableId,
            gateGroupCQueueableId,
            gateGroupDQueueableId,
            gateGroupEQueueableId,
            gateGroupFQueueableId
        };
        List<EnqueuedGateItem__c> gateItemsAfter = [SELECT Id, Name FROM EnqueuedGateItem__c];
        Integer actualGateGroupsAfterSize = gateGroupsAfter.size();
        Integer actualGateItemsAfterSize = gateItemsAfter.size();

        Boolean actualGateItemsFlag = true;
        Set<Id> expectedGateItemIds = new Set<Id>{
            gateItem09.Id, gateItem10.Id, gateItem11.Id, gateItem12.Id
        };
        for (EnqueuedGateItem__c gateItem : gateItemsAfter) {
            if (!expectedGateItemIds.contains(gateItem.Id))
                actualGateItemsFlag = false;
        }

        // assert:
        Integer expectedGateItemsAfterSize = 4;
        System.assertEquals(expectedGateItemsAfterSize,actualGateItemsAfterSize);
        Boolean expectedGateItemsFlag = true;
        System.assertEquals(expectedGateItemsFlag,actualGateItemsFlag);
    }


    static testmethod void callingDeleteGateGroupsPerformsNOOPWhenIsEnabledEqFalse() {
        // arrange:
        String overThreshold = 'OVER'; // implies an "old" gate item record - conceptually older than "n" days
        Integer maximumItems = 5;      // the maximum number of gate item records

        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';
        String gateGroupDQueueableId = 'D1234567';
        String gateGroupEQueueableId = 'E1234567';
        String gateGroupFQueueableId = 'F1234567';


        // inserted in "order"
        // gateItem01 is the oldest
        // gateItem12 is the newest
        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId, Event__c = overThreshold);
        insert gateItem01;
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId, Event__c = overThreshold);
        insert  gateItem02;
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId, Event__c = overThreshold);
        insert  gateItem03;
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem04;
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem05;
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem06;
        EnqueuedGateItem__c gateItem07 = new EnqueuedGateItem__c(GateGroup__c = gateGroupDQueueableId);
        insert  gateItem07;
        EnqueuedGateItem__c gateItem08 = new EnqueuedGateItem__c(GateGroup__c = gateGroupDQueueableId);
        insert  gateItem08;
        EnqueuedGateItem__c gateItem09 = new EnqueuedGateItem__c(GateGroup__c = gateGroupEQueueableId);
        insert  gateItem09;
        EnqueuedGateItem__c gateItem10 = new EnqueuedGateItem__c(GateGroup__c = gateGroupEQueueableId);
        insert  gateItem10;
        EnqueuedGateItem__c gateItem11 = new EnqueuedGateItem__c(GateGroup__c = gateGroupFQueueableId);
        insert  gateItem11;
        EnqueuedGateItem__c gateItem12 = new EnqueuedGateItem__c(GateGroup__c = gateGroupFQueueableId);
        insert  gateItem12;

        EnqueuedGate.IEnqueuedGateItemProvider EnqueuedGateItemProviderTime =
            new EnqueuedGate.MockEnqueuedGateItemProviderTime(overThreshold);
        EnqueuedGate.IEnqueuedGateItemProvider EnqueuedGateItemProviderCount =
            new EnqueuedGate.EnqueuedGateItemProviderCount(maximumItems);

        Boolean isEnabled = false;

        // expectations :
        //  - NOOP
        //  - thus 12 gate items (01 - 12) and 6 gate groups(A - F) will survive

        // act:
        EnqueuedGate.EnqueuedGateDeletionProvider gateDeletionProvider =
            new EnqueuedGate.EnqueuedGateDeletionProvider(isEnabled, EnqueuedGateItemProviderTime, EnqueuedGateItemProviderCount);
        gateDeletionProvider.deleteEnqueuedGateGroups();

        // assemble:
        List<String> gateGroupsAfter = new List<String>{
            gateGroupAQueueableId,
            gateGroupBQueueableId,
            gateGroupCQueueableId,
            gateGroupDQueueableId,
            gateGroupEQueueableId,
            gateGroupFQueueableId
        };
        List<EnqueuedGateItem__c> gateItemsAfter = [SELECT Id, Name FROM EnqueuedGateItem__c];
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
        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        List<EnqueuedGateItem__c> gateItems = new List<EnqueuedGateItem__c>{
            gateItem01,
            gateItem03,
            gateItem04,
            gateItem06
        };
        insert gateItems;

        // act:
        Set<String> actualGateGroupIds = EnqueuedGate.getEnqueuedGateGroupIds(gateItems);

        // assert:
        Set<String> expectedGateGroupIds = new Set<String>{gateGroupAQueueableId, gateGroupCQueueableId};
        System.assertEquals(expectedGateGroupIds, actualGateGroupIds);
    }


    static testmethod void callingGetGateItemsOverDateThresholdMockReturnsExpectedGateItems() {
        // arrange:
        String overThreshold = 'OVER';

        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId, Event__c = null);
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId, Event__c = overThreshold);
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId, Event__c = null);
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId, Event__c = null);
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId, Event__c = overThreshold);
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId, Event__c = null);
        List<EnqueuedGateItem__c> gateItems = new List<EnqueuedGateItem__c> {
            gateItem01,
            gateItem02,
            gateItem03,
            gateItem04,
            gateItem05,
            gateItem06
        };
        insert gateItems;

        // act:
        List<EnqueuedGateItem__c> actualGateItems =
            EnqueuedGate.getEnqueuedGateItemsOverDateThresholdMock(overThreshold);

        // assemble
        Set<Id> actualGateItemIds = (new Map<Id, EnqueuedGateItem__c>(actualGateItems)).keySet();

        // assert:
        Set<Id> expectedGateItemIds = new Set<Id>{gateItem02.Id, gateItem05.Id};
        System.assertEquals(expectedGateItemIds, actualGateItemIds);
    }


    static testmethod void callingGetCountThresholdReturnsExpectedCountThreshold() {
        // arrange:
        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        List<EnqueuedGateItem__c> gateItems = new List<EnqueuedGateItem__c> {
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
        Integer actualCountThreshold = EnqueuedGate.getCountThreshold(maximumItems);

        // assert:
        Integer expectedCountThreshold = delta;
        System.assertEquals(expectedCountThreshold, actualCountThreshold);
    }


    static testmethod void callingGetDateThresholdReturnsDateTimeEarlierThanNow() {
        // arrange:
        DateTime now = System.now() ;
        Integer maximumDays  =  30;

        // act:
        DateTime actualDateThreshold = EnqueuedGate.getDateThreshold(now, maximumDays);

        // assert
        System.assert(now > actualDateThreshold);
    }


    static testmethod void callingGetGateItemsOverCountThresholdReturnsExpectedGateItems() {
        // arrange:
        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        insert gateItem01;
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem02;
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem03;
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        insert  gateItem04;
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem05;
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem06;

        Integer maximumItems = 4;
        Integer countThreshold = EnqueuedGate.getCountThreshold(maximumItems);

        // act:
        List<EnqueuedGateItem__c> actualGateItemsOverCountThreshold =
            EnqueuedGate.getEnqueuedGateItemsOverCountThreshold(countThreshold);

        // assemble:
        Integer actualSize = actualGateItemsOverCountThreshold.size();
        Set<Id> actualGateItemIds = (new Map<Id,EnqueuedGateItem__c >(actualGateItemsOverCountThreshold)).keySet();

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
        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        List<EnqueuedGateItem__c> gateItems = new List<EnqueuedGateItem__c>{
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
        List<EnqueuedGateItem__c> actualGateItems  =
            EnqueuedGate.getEnqueuedGateItemsOverDateThresholdImpl(dateThreshold);

        // assemble:
        Integer actualSize = actualGateItems.size();

        // assert:
        Integer expectedSize = 0;
        System.assertEquals(expectedSize, actualSize);
    }


    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds01() {
        // arrange:
        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        insert gateItem01;
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        insert  gateItem02;
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem03;
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem04;
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem05;
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem06;

        Integer maximumItems = 4;

        // act:
        EnqueuedGate.IEnqueuedGateItemProvider EnqueuedGateItemProvider = new EnqueuedGate.EnqueuedGateItemProviderCount(maximumItems);
        Set<String> actualGateGroupIds = EnqueuedGateItemProvider.getEnqueuedGateGroupIds();

        // assemble:
        Integer actualSize = actualGateGroupIds.size();

        // assert:
        Integer expectedSize = 1;
        System.assertEquals(expectedSize,actualSize );
        Set<String> expectedGateGroupIds = new Set<String>{gateGroupAQueueableId};
        System.assertEquals(expectedGateGroupIds,actualGateGroupIds);
    }


    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds02() {
        // arrange:
        String overThreshold = 'OVER';

        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId, Event__c = overThreshold);
        insert gateItem01;
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId, Event__c = overThreshold);
        insert  gateItem02;
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem03;
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem04;
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem05;
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem06;

        // act:
        EnqueuedGate.IEnqueuedGateItemProvider EnqueuedGateItemProvider = new EnqueuedGate.MockEnqueuedGateItemProviderTime(overThreshold);
        Set<String> actualGateGroupIds = EnqueuedGateItemProvider.getEnqueuedGateGroupIds();

        // assemble:
        Integer actualSize = actualGateGroupIds.size();

        // assert:
        Integer expectedSize = 1;
        System.assertEquals(expectedSize,actualSize );
        Set<String> expectedGateGroupIds = new Set<String>{gateGroupAQueueableId};
        System.assertEquals(expectedGateGroupIds,actualGateGroupIds);
    }


    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds03A() {
        // arrange:
        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        insert gateItem01;
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        insert  gateItem02;
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem03;
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem04;
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem05;
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem06;

        Integer arbitarySMALLOffsetIntoFuture = 2;
        DateTime X = system.now().addDays(arbitarySMALLOffsetIntoFuture);
        Integer maximumDays = 30;

        //  <---too old---||---- acceptable ----| true now |------"future" --------- >
        //  X = "now" + arbitarySMALLOffsetIntoFuture
        //  <---too old---||---- acceptable ----| true now |-- X ----"future" ------- >

        // act:
        EnqueuedGate.IEnqueuedGateItemProvider EnqueuedGateItemProvider = new EnqueuedGate.EnqueuedGateItemProviderTime(X, maximumDays);
        Set<String> actualGateGroupIds = EnqueuedGateItemProvider.getEnqueuedGateGroupIds();

        // assemble:
        Integer actualSize = actualGateGroupIds.size();

        // assert:
        Integer expectedSize = 0;
        System.assertEquals(expectedSize,actualSize );
    }


    static testmethod void callingGetGateGroupIdsReturnsExpectedGateGroupIds03B() {
        // arrange:
        String gateGroupAQueueableId = 'A1234567';
        String gateGroupBQueueableId = 'B1234567';
        String gateGroupCQueueableId = 'C1234567';


        EnqueuedGateItem__c gateItem01 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        insert gateItem01;
        EnqueuedGateItem__c gateItem02 = new EnqueuedGateItem__c(GateGroup__c = gateGroupAQueueableId);
        insert  gateItem02;
        EnqueuedGateItem__c gateItem03 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem03;
        EnqueuedGateItem__c gateItem04 = new EnqueuedGateItem__c(GateGroup__c = gateGroupBQueueableId);
        insert  gateItem04;
        EnqueuedGateItem__c gateItem05 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem05;
        EnqueuedGateItem__c gateItem06 = new EnqueuedGateItem__c(GateGroup__c = gateGroupCQueueableId);
        insert  gateItem06;

        Integer arbitaryOffset  = 2;
        Integer maximumDays = 30;
        Integer arbitaryLARGEOffsetIntoFuture = maximumDays + arbitaryOffset;
        DateTime X = system.now().addDays(arbitaryLARGEOffsetIntoFuture);

        //  <---too old---||---- acceptable ----| true now |------"future" --------- >
        //  X = "true now" + arbitaryLARGEOffsetIntoFuture
        //  <---too old---||---- acceptable ----| true now |------"future" --------- X --------- >

        // act:
        EnqueuedGate.IEnqueuedGateItemProvider EnqueuedGateItemProvider = new EnqueuedGate.EnqueuedGateItemProviderTime(X, maximumDays);
        Set<String> actualGateGroupIds = EnqueuedGateItemProvider.getEnqueuedGateGroupIds();

        // assemble:
        Integer actualSize = actualGateGroupIds.size();

        // assert:
        Integer expectedSize = 3;
        System.assertEquals(expectedSize,actualSize );
    }
  
}