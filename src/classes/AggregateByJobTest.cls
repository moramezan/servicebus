@IsTest class AggregateByJobTest {

   static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(AggregateByJob.class);

        //assert
        Integer expectedLimits = 200; //max sync limit
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }


   static testmethod void withinSystemLimits() {
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(AggregateByJob.class);
        Integer limits = summary.Limits;

        // Arrange
        Integer rangeCount =  limits;
        Integer otherCount  = 4;
        Integer totalCount = rangeCount + otherCount;
        String jobId = '707000000000000AAA';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'JobId' => jobId,
            'Route' => 'Test#1',
            'Range' => rangeCount,
            'Chunk' => null,
            'SiblingIds' => null
        };

        List<Message__c> rangeMessages = new List<Message__c> ();
        Integer z = 1;
        while (z <= rangeCount) {
            rangeMessages.add( new Message__c(Status__c = 'Started', JobId__c = jobId ) );
            z++;
        }
        insert rangeMessages;
        Set<Id> siblingIds =  new Map<Id,Message__c>(rangeMessages).keySet();


        List<Message__c> otherMessages = new List<Message__c> ();
        z = 1;
        while (z <= otherCount) {
            otherMessages.add(new Message__c(Status__c = 'Completed', JobId__c = jobId) );  //Completed
            z++;
        }
        insert otherMessages;

        //act
        Test.startTest();
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            Map<String,Object> inputEvent = templateEvent.clone();
            inputEvent.put('SiblingIds' , siblingIds);
            inputEvent.put('Chunk' , i+1);

            ApexClassModel.Service service = new AggregateByJob();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');

   }


    static testmethod void callingIsReleaseThrowsExpectedException01() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            //'JobId' => '707000000000000AAA',
            'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJob();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (Exception e) {
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
            'JobId' => '707000000000000AAA',
            //'Route' => 'test',
            'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJob();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (Exception e) {
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
            'JobId' => '707000000000000AAA',
            'Route' => 'Test#1',
            //'Range' => 1,
            'Chunk' => 1,
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJob();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (Exception e) {
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
            'JobId' => '707000000000000AAA',
            'Route' => 'Test#1',
            'Range' => 1,
            //'Chunk' => 1
            'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJob();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (Exception e) {
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
            'JobId' => '707000000000000AAA',
            'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1
            //'SiblingIds' => new Set<Id>{'000000000000000AAA'}
        };

        Boolean actualFlag = false;
        try {
            ApexClassModel.Service service = new AggregateByJob();
            List<Map<String,Object>> actualOutputEvents = service.handle(inputEvent);
        } catch (Exception e) {
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
        String jobId = '707000000000000AAA';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'JobId' => jobId,
            'Route' => 'Test#1',
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
        ApexClassModel.Service service = new AggregateByJob();
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
        String jobId = '707000000000000AAA';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'JobId' => jobId,
            'Route' => 'Test#1',
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
        ApexClassModel.Service service = new AggregateByJob();
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
        String jobId = '707000000000000AAA';

        Map<String,Object> templateEvent = new Map<String,Object> {
            'JobId' => jobId,
            'Route' => 'Test#1',
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
        ApexClassModel.Service service = new AggregateByJob();
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
        Map<String,Object> actualCommonParameters = AggregateByJob.getCommonParameters(gateItems);

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
        Map<String,Object> actualCommonParameters = AggregateByJob.getCommonParameters(gateItems);

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
        Map<String,Object> actualCommonParameters = AggregateByJob.getCommonParameters(gateItems);

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
        Map<String,Object> actualParameters =  AggregateByJob.cleanParameters(parameters);

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
        String jobId = '707000000000000AAA';
        Integer chunkTotal = 1;
        Integer chunk = 1;

        Message__c message = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message;
        Set<Id> siblingIds =  new Set<Id>{ message.Id };

        // Act :
        Boolean actualIsRelease = AggregateByJob.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected02() {
        // Arrange :
        String jobId = '707000000000000AAA';
        Integer chunkTotal = 2;
        Integer chunk = 1;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByJob.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected03() {
        // Arrange :
        String jobId = '707000000000000AAA';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c message1 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message1;
        Message__c message2 = new Message__c( Status__c = 'Started', Event__c = '{"JobId":"' + jobId + '"}');
        insert message2;
        Set<Id> siblingIds =  new Set<Id>{ message1.Id,  message2.Id };


        // Act :
        Boolean actualIsRelease = AggregateByJob.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected04() {
        // Arrange :
        String jobId = '707000000000000AAA';
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
        Boolean actualIsRelease = AggregateByJob.isRelease(siblingIds, jobId, chunkTotal, chunk);

        // Assemble :
        // n/a

        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected05() {
        // Arrange :
        String jobId = '707000000000000AAA';
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
        Boolean actualIsRelease = AggregateByJob.isRelease(siblingIds, jobId, chunkTotal, chunk);

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
    
    public class SplitSummary {
        String Description = 'the big split';
    }

    static testmethod void testBrokerAggregateSiblings() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel.fromId(sequence.Id).appendStep(Split.class);
        SequenceModel.fromId(sequence.Id).appendStep(AggregateByJob.class);
        SequenceModel.fromId(sequence.Id).appendStep(Terminate.class);
        
        //act (enqueue)
        Test.startTest();
        SequenceModel.fromId(sequence.Id).enqueueTestMessage();
        Test.stopTest();
        
        //act (broker)
        Broker.impl().run();
        
        //assert
        Integer expectedCount = 7;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong count. Gate probably did not release.');
    }
    
}