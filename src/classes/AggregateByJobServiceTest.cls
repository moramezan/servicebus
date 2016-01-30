@IsTest class AggregateByJobServiceTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }

    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Definition definition = new ApexClassModel.Definition(AggregateByJobService.class);

        //assert
        Integer expectedChunks = 100; //max sync limit
        Integer actualChunks = definition.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }


   static testmethod void withinSystemLimits() {
        //assemble
        ApexClassModel.Definition definition = new ApexClassModel.Definition(AggregateByJobService.class);
        Integer chunks = definition.Chunks;

        // Arrange
        Integer rangeCount =  chunks;
        Integer otherCount  = 4;
        Integer totalCount = rangeCount + otherCount;

        Map<String,Object> templateEvent = new Map<String,Object> {
            'Route' => '1#Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer z = 1;
        while (z <= rangeCount) {
            Id jobId = 'a01000000000' + (100 + z);
            rangeMessages.add( new Message__c(Status__c = 'Started', JobId__c = jobId ) );
            z++;
        }
        insert rangeMessages;
        Set<Id> siblingIds =  new Map<Id,Message__c>(rangeMessages).keySet();


        List<Message__c> otherMessages = new List<Message__c> ();
        z = 1;
        while (z <= otherCount) {
            Id jobId = 'a01000000000' + (100 + z);
            otherMessages.add(new Message__c(Status__c = 'Completed', JobId__c = jobId) );  //Completed
            z++;
        }
        insert otherMessages;

        //act
        Test.startTest();
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            Map<String,Object> inputEvent = templateEvent.clone();
            inputEvent.put('JobId', 'a01000000000' + (100 + i));
            inputEvent.put('SiblingIds' , siblingIds);
            inputEvent.put('Chunk' , i+1);

            ApexClassModel.Service service = new AggregateByJobService();
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
            'Route' => '1#Test#1',
            'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJobService();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByJobService.ServiceException e) {
            actualFlag = e.getMessage().contains('missing mandatory JobId');
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
            'JobId' => '707000123456789',
            //'Route' => 'test',
            'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJobService();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByJobService.ServiceException e) {
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
            'JobId' => '707000123456789',
            'Route' => '1#Test#1',
            //'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJobService();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByJobService.ServiceException e) {
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
            'JobId' => '707000123456789',
            'Route' => '1#Test#1',
            'Range' => 1,
            //'Chunk' => 1
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJobService();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByJobService.ServiceException e) {
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
            'JobId' => '707000123456789',
            'Route' => '1#Test#1',
            'Range' => 1,
            'Chunk' => 1
            //'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJobService();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (AggregateByJobService.ServiceException e) {
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
        Id jobId = '707000123456789';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'JobId' => jobId,
            'Route' => '1#Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer i = 1;
        while (i <= rangeCount) {
            rangeMessages.add( new Message__c(Status__c = 'Started' , JobId__c = jobId) );
            i++;
        }
        insert rangeMessages;
        List<Id> siblingIds = new List<Id>((new Map<Id,Message__c>(rangeMessages)).keySet());

        List<Message__c> otherMessages = new List<Message__c> ();
        i = 1;
        while (i <= otherCount) {
            otherMessages.add(new Message__c(Status__c = 'Completed' , JobId__c = jobId) );  // Completed
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
        ApexClassModel.Service service = new AggregateByJobService();
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
        Id jobId = '707000123456789';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'JobId' => jobId,
            'Route' => '1#Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer i = 1;
        while (i <= rangeCount) {
            rangeMessages.add( new Message__c(Status__c = 'Started', JobId__c = jobId ) );
            i++;
        }
        insert rangeMessages;
        Set<Id> siblingIds =  new Map<Id,Message__c>(rangeMessages).keySet();


        List<Message__c> otherMessages = new List<Message__c> ();
        i = 1;
        while (i <= otherCount) {
            otherMessages.add(new Message__c(Status__c = 'Completed', JobId__c = jobId) );  //Completed
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
        ApexClassModel.Service service = new AggregateByJobService();
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
        Id jobId = '707000123456789';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'JobId' => jobId,
            'Route' => '1#Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer i = 1;
        while (i <= rangeCount) {
            rangeMessages.add( new Message__c(Status__c = 'Started',  JobId__c = jobId ) );
            i++;
        }
        insert rangeMessages;
        List<Id> siblingIds = new List<Id>((new Map<Id,Message__c>(rangeMessages)).keySet());

        List<Message__c> otherMessages = new List<Message__c> ();
        i = 1;
        while (i <= otherCount) {
            otherMessages.add(new Message__c(Status__c = 'Buffered', JobId__c = jobId) );  //Buffered or Paused
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
        ApexClassModel.Service service = new AggregateByJobService();
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
        Map<String,Object> actualCommonParameters = AggregateByJobService.getCommonParameters(gateItems);

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
        Map<String,Object> actualCommonParameters = AggregateByJobService.getCommonParameters(gateItems);

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
        Map<String,Object> actualCommonParameters = AggregateByJobService.getCommonParameters(gateItems);

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
            'services:x' => 'v2',
            'balls' => 'v3'
        };

        // Act
        Map<String,Object> actualParameters =  AggregateByJobService.cleanParameters(parameters);

        // prepare
        Boolean actual01 = (actualParameters.get(':x') != null);
        Boolean actual02 = (actualParameters.get('services:x') != null);
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
        Id jobId = '707000123456789';
        Integer chunkTotal = 1;
        Integer chunk = 1;

        Message__c message = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message;
        Set<Id> siblingIds =  new Set<Id>{ message.Id };

        // Act :
        Boolean actualIsRelease = AggregateByJobService.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected02() {
        // Arrange :
        Id jobId = '707000123456789';
        Integer chunkTotal = 2;
        Integer chunk = 1;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByJobService.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected03() {
        // Arrange :
        Id jobId = '707000123456789';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByJobService.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected04() {
        // Arrange :
        Id jobId = '707000123456789';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c messageB = new Message__c( Status__c = 'Buffered', Event__c = '{"JobId":"' + jobId + '"}');
        insert messageB;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByJobService.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected05() {
        // Arrange :
        Id jobId = '707000123456789';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c messageB = new Message__c( Status__c = 'Completed', Event__c = '{"JobId":"' + jobId + '"}');
        insert messageB;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByJobService.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    public class Split extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{'RecordId' => '001,Account'},
                new Map<String,Object>{'RecordId' => '0ca,ChatterActivity'},
                new Map<String,Object>{'RecordId' => '0cs,OauthConsumerScope'},
                new Map<String,Object>{'RecordId' => '0eb,EntityBlacklist'},
                new Map<String,Object>{'RecordId' => '0en,Endorsement'}
            };
        }
    }
    
    public class SplitDefinition extends ApexClassModel.Definition {
        String Description = 'the big split';
    }

    static testmethod void testBrokerAggregateSiblings() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel.fromId(sequence.Id).appendStep(Split.class.getName());
        SequenceModel.fromId(sequence.Id).appendStep(AggregateByJobService.class.getName());
        SequenceModel.fromId(sequence.Id).appendStep(TerminateService.class.getName());
        
        //act (enqueue)
        Test.startTest();
        SequenceModel.fromId(sequence.Id).enqueueTestMessage();
        Test.stopTest();
        
        //act (broker)
        Broker.impl().run();
        
        //assert
        Integer expectedCount = 7;
        Integer actualCount = [SELECT COUNT() FROM Message__c ALL ROWS]; //#1114 in the recycle bin
        System.assertEquals(expectedCount, actualCount, 'Wrong count. Gate probably did not release.');
    }
    
}