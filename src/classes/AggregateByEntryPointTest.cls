@IsTest class AggregateByEntryPointTest {

   static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(AggregateByEntryPoint.class);

        //assert
        Integer expectedChunks = 200; //max sync limit
        Integer actualChunks = summary.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }


   static testmethod void withinSystemLimits() {
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(AggregateByEntryPoint.class);
        Integer chunks = summary.Chunks;

        // Arrange
        Integer rangeCount =  chunks;
        Integer otherCount  = 4;
        Integer totalCount = rangeCount + otherCount;
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'EntryPointUuid' => EntryPointUuid,
            'Route' => 'Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer z = 1;
        while (z <= rangeCount) {
            rangeMessages.add( new Message__c(Status__c = 'Started', EntryPointUuid__c = entryPointUuid ) );
            z++;
        }
        insert rangeMessages;
        Set<Id> siblingIds =  new Map<Id,Message__c>(rangeMessages).keySet();


        List<Message__c> otherMessages = new List<Message__c> ();
        z = 1;
        while (z <= otherCount) {
            otherMessages.add(new Message__c(Status__c = 'Completed', EntryPointUuid__c = entryPointUuid) );  //Completed
            z++;
        }
        insert otherMessages;

        //act
        Test.startTest();
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            Map<String,Object> inputEvent = templateEvent.clone();
            inputEvent.put('SiblingIds' , siblingIds);
            inputEvent.put('Chunk' , i+1);

            ApexClassModel.Service service = new AggregateByEntryPoint();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');

   }


    static testmethod void callingIsReleaseThrowsExpectedException01() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            //'EntryPointUuid' => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
            'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByEntryPoint.ServiceException e) {
            actualFlag = e.getMessage().contains('missing mandatory EntryPointUuid');
        }

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag , actualFlag);
    }


    static testmethod void callingIsReleaseThrowsExpectedException02() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            'EntryPointUuid' => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
            //'Route' => 'test',
            'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByEntryPoint.ServiceException e) {
            actualFlag = e.getMessage().contains('missing mandatory Route');
        }

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag , actualFlag);
    }

    static testmethod void callingIsReleaseThrowsExpectedException04() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            'EntryPointUuid' => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
            'Route' => 'Test#1',
            //'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByEntryPoint.ServiceException e) {
            actualFlag = e.getMessage().contains('missing mandatory Range');
        }

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag , actualFlag);
    }

    static testmethod void callingIsReleaseThrowsExpectedException05() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            'EntryPointUuid' => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
            'Route' => 'Test#1',
            'Range' => 1,
            //'Chunk' => 1
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByEntryPoint.ServiceException e) {
            actualFlag = e.getMessage().contains('missing mandatory Chunk');
        }

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag , actualFlag);
    }

    static testmethod void callingIsReleaseThrowsExpectedException06() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            'EntryPointUuid' => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
            'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1
            //'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByEntryPoint.ServiceException e) {
            actualFlag = e.getMessage().contains('missing mandatory SiblingIds');
        }

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag , actualFlag);
    }




    static testmethod void  callingExecuteReturnsOneWhenLastInChunkAndOthersInGroupCompleted() {
        // Arrange
        Integer totalCount = 5;
        Integer rangeCount =  3 ;
        Integer otherCount  = totalCount - rangeCount;
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'EntryPointUuid' => EntryPointUuid,
            'Route' => 'Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer i = 1;
        while (i <= rangeCount) {
            rangeMessages.add( new Message__c(Status__c = 'Started' , EntryPointUuid__c = entryPointUuid) );
            i++;
        }
        insert rangeMessages;
        List<Id> siblingIds = new List<Id>((new Map<Id,Message__c>(rangeMessages)).keySet());

        List<Message__c> otherMessages = new List<Message__c> ();
        i = 1;
        while (i <= otherCount) {
            otherMessages.add(new Message__c(Status__c = 'Completed' , EntryPointUuid__c = entryPointUuid) );  // Completed
            i++;
        }
        insert otherMessages;

        Map<Integer,Map<String,Object>> chunkToEvent = new Map<Integer,Map<String,Object>>();
        i = 1;
        while(i <= rangeCount) {
            Map<String,Object> event = templateEvent.clone();
            event.put('SiblingIds' , siblingIds);
            event.put('Chunk' , i);
            chunkToEvent.put(i,event);
            rangeMessages[i-1].Event__c = json.serialize(event);
            i++;
        }
        update rangeMessages;

        // last event
        Integer lastOffset = rangeCount;
        Map<String,Object> inputEvent = chunkToEvent.get(rangeCount);

        // Act
        ApexClassModel.Service service = new AggregateByEntryPoint();
        List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);

        // Assemble
        Integer actualSize = actualOutputEvents.size();

        // Assert
        Integer expectedSize = 1;
        System.assertEquals(expectedSize , actualSize);
    }


    static testmethod void  callingExecuteReturnsZeroWhenNotLastInChunkAndOthersInGroupCompleted() {
        // Arrange
        Integer totalCount = 5;
        Integer rangeCount =  3 ;
        Integer otherCount  = totalCount - rangeCount;
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'EntryPointUuid' => EntryPointUuid,
            'Route' => 'Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer i = 1;
        while (i <= rangeCount) {
            rangeMessages.add( new Message__c(Status__c = 'Started', EntryPointUuid__c = entryPointUuid ) );
            i++;
        }
        insert rangeMessages;
        Set<Id> siblingIds =  new Map<Id,Message__c>(rangeMessages).keySet();


        List<Message__c> otherMessages = new List<Message__c> ();
        i = 1;
        while (i <= otherCount) {
            otherMessages.add(new Message__c(Status__c = 'Completed', EntryPointUuid__c = entryPointUuid) );  //Completed
            i++;
        }
        insert otherMessages;

        Map<Integer,Map<String,Object>> chunkToEvent = new Map<Integer,Map<String,Object>>();
        i = 1;
        while(i <= rangeCount) {
            Map<String,Object> event = templateEvent.clone();
            event.put('SiblingIds' , siblingIds);
            event.put('Chunk' , i);
            chunkToEvent.put(i,event);
            rangeMessages[i-1].Event__c = json.serialize(event);
            i++;
        }
        update rangeMessages;

        // NOT last event
        Integer lastOffset = rangeCount;
        Integer notLastOffset = lastOffset - 1;
        Map<String,Object> inputEvent = chunkToEvent.get(notLastOffset);

        // Act
        ApexClassModel.Service service = new AggregateByEntryPoint();
        List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);

        // Assemble
        Integer actualSize = actualOutputEvents.size();

        // Assert
        Integer expectedSize = 0;
        System.assertEquals(expectedSize , actualSize);
    }



    static testmethod void  callingExecuteReturnsZeroWhenOthersInGroupBufferedOrPaused() {
        // Arrange
        Integer totalCount = 5;
        Integer rangeCount =  3 ;
        Integer otherCount  = totalCount - rangeCount;
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'EntryPointUuid' => EntryPointUuid,
            'Route' => 'Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer i = 1;
        while (i <= rangeCount) {
            rangeMessages.add( new Message__c(Status__c = 'Started',  EntryPointUuid__c = entryPointUuid ) );
            i++;
        }
        insert rangeMessages;
        List<Id> siblingIds = new List<Id>((new Map<Id,Message__c>(rangeMessages)).keySet());

        List<Message__c> otherMessages = new List<Message__c> ();
        i = 1;
        while (i <= otherCount) {
            otherMessages.add(new Message__c(Status__c = 'Buffered', EntryPointUuid__c = entryPointUuid) );  //Buffered or Paused
            i++;
        }
        insert otherMessages;

        Map<Integer,Map<String,Object>> chunkToEvent = new Map<Integer,Map<String,Object>>();
        i = 1;
        while(i <= rangeCount) {
            Map<String,Object> event = templateEvent.clone();
            event.put('SiblingIds' , siblingIds);
            event.put('Chunk' , i);
            chunkToEvent.put(i,event);
            rangeMessages[i-1].Event__c = json.serialize(event);
            i++;
        }
        update rangeMessages;

        // last event
        Integer lastOffset = rangeCount;
        Map<String,Object> inputEvent = chunkToEvent.get(lastOffset);

        // Act
        ApexClassModel.Service service = new AggregateByEntryPoint();
        List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);

        // Assemble
        Integer actualSize = actualOutputEvents.size();

        // Assert
        Integer expectedSize = 0;
        System.assertEquals(expectedSize , actualSize);
    }




    static testmethod void callingGetCommonParametersReturnsExpectedCollection01() {
        // Arrange :
        List<Message__c> gateItems = new List<Message__c>{
            new Message__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => 'v1',
                        'p2' => 'v2'
                    }
                )
            ),
            new Message__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => 'v1',
                        'p2' => 'v2'
                    }
                )
            )
        };

        // Act
        Map<String,Object> actualCommonParameters = AggregateByEntryPoint.getCommonParameters(gateItems);

        // prepare
        Integer actualSize = actualCommonParameters.keySet().size();

        // Assert
        Integer expectedSize = 2;
        System.assertEquals(expectedSize , actualSize );
    }



    static testmethod void callingGetCommonParametersReturnsExpectedCollection02() {
        // Arrange :
        List<Message__c> gateItems = new List<Message__c>{
            new Message__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => 'v1',
                        'p2' => 'v2',
                        'p3' => 'v3'   // not present on all
                    }
                )
            ),
            new Message__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => 'v1',
                        'p2' => 'v2'
                    }
                )
            )
        };

        // Act
        Map<String,Object> actualCommonParameters = AggregateByEntryPoint.getCommonParameters(gateItems);

        // prepare
        Integer actualSize = actualCommonParameters.keySet().size();
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
        List<Message__c> gateItems = new List<Message__c>{
            new Message__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => null,  // present on all, but null
                        'p2' => 'v2',
                        'p3' => 'v3'   // not present on all
                    }
                )
            ),
            new Message__c(
                Event__c = json.serialize(
                    new Map<String,Object> {
                        'p1' => null, // present on all, but null
                        'p2' => 'v2'
                    }
                )
            )
        };

        // Act
        Map<String,Object> actualCommonParameters = AggregateByEntryPoint.getCommonParameters(gateItems);

        // prepare
        Integer actualSize = actualCommonParameters.keySet().size();
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
            ':x' => 'v1',
            'servicebus:x' => 'v2',
            'balls' => 'v3'
        };

        // Act
        Map<String,Object> actualParameters =  AggregateByEntryPoint.cleanParameters(parameters);

        // prepare
        Boolean actual01 = (actualParameters.get(':x') != null);
        Boolean actual02 = (actualParameters.get('servicebus:x') != null);
        Boolean actual03 = (actualParameters.get('balls') == null);

        // Assert
        Boolean expected01 = true;
        System.assertEquals(expected01 , actual01);
        Boolean expected02 = true;
        System.assertEquals(expected02 , actual02);
        Boolean expected03 = true;
        System.assertEquals(expected03 , actual03);
    }



    static testmethod void callingIsReleaseReturnsExpectedExpected01() {
        // Arrange :
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 1;
        Integer chunk = 1;

        Message__c message = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message;
        Set<Id> siblingIds =  new Set<Id>{ message.Id };

        // Act :
        Boolean actualIsRelease = AggregateByEntryPoint.isRelease(siblingIds, EntryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected02() {
        // Arrange :
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 2;
        Integer chunk = 1;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByEntryPoint.isRelease(siblingIds, EntryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected03() {
        // Arrange :
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByEntryPoint.isRelease(siblingIds, EntryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected04() {
        // Arrange :
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c messageB = new Message__c( Status__c = 'Buffered', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert messageB;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByEntryPoint.isRelease(siblingIds, EntryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected05() {
        // Arrange :
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c messageB = new Message__c( Status__c = 'Completed', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert messageB;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"EntryPointUuid":"' + EntryPointUuid + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByEntryPoint.isRelease(siblingIds, EntryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

}