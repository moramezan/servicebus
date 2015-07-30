@IsTest public class GateByJobTest {

    static testmethod void callingIsReleaseThrowsExpectedException01() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            //   '__QueueableId' => '12345',
            '__SequenceName' => 'test',
            '__Position' => 1,
            '__ChunkTotal' => 1,
            '__Chunk' => 1
        };
                    
        Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByJob();
            List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);
        } catch (Exception e) {
            actualFlag = e.getMessage().contains('missing mandatory __QueueableId');
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
            '__QueueableId' => '12345',
            // '__SequenceName' => 'test',
            '__Position' => 1,
            '__ChunkTotal' => 1,
            '__Chunk' => 1
        };
                    
        Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByJob();
            List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);
        } catch (Exception e) {
            actualFlag = e.getMessage().contains('missing mandatory __SequenceName');
        }
        
        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag , actualFlag);
    }
    
    static testmethod void callingIsReleaseThrowsExpectedException03() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            '__QueueableId' => '12345',
            '__SequenceName' => 'test',
            // '__Position' => 1,
            '__ChunkTotal' => 1,
            '__Chunk' => 1
        };
                    
                    Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByJob();
            List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);
        } catch (Exception e) {
            actualFlag = e.getMessage().contains('missing mandatory __Position');
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
            '__QueueableId' => '12345',
            '__SequenceName' => 'test',
            '__Position' => 1,
            // '__ChunkTotal' => 1,
            '__Chunk' => 1
        };
                    
        Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByJob();
            List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);
        } catch (Exception e) {
            actualFlag = e.getMessage().contains('missing mandatory  __ChunkTotal');
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
            '__QueueableId' => '12345',
            '__SequenceName' => 'test',
            '__Position' => 1,
            '__ChunkTotal' => 1
            // '__Chunk' => 1
        };
                    
        Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByJob();
            List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);
        } catch (Exception e) {
            actualFlag = e.getMessage().contains('missing mandatory __Chunk');
        }
        
        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag , actualFlag);
    }
     
    
    static testmethod void callingInvokeMainReturnsZeroOutputEventsWhenPersistedCountNotEqOneWithStartedStatus() {
        // Arrange
        Integer count =  3 ;
        Integer insertIntoMessageCount = count;

        String queueableId = '1234567';

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__QueueableId' => queueableId,
            '__SequenceName' => 'test',
            '__Position' => 1,
            '__ChunkTotal' => 1,
            '__Chunk' => 1
        };

        List<Message__c> messages = new List<Message__c> ();
        integer i = 1;
        while(i <= count) {
            Map<String,Object> event = inputEvent.clone();
            event.put('c__data' , 'x'+i);
            if (i <= insertIntoMessageCount) {
                String status = (i == insertIntoMessageCount) ? 'Started' : 'Buffered';
                messages.add(new Message__c(Event__c = json.serialize(event), Status__c = status));
            }

            i++;
        }
        insert messages;

        // Act
        ApexClassModel.BaseProcess process = new GateByJob();
        List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);

        // Assemble
        Integer actualSize = actualOutputEvents.size();

        // Assert
        Integer expectedSize = 0;
        System.assertEquals(expectedSize , actualSize);
    }



    static testmethod void callingInvokeMainReturnsOneOutputEventWhenPersistedCountEqOneWithStartedStatus() {
        // Arrange
        Integer count =  3 ;
        Integer insertIntoMessageCount = count;
        Integer insertIntoGateItemCount = count - 1;  // Adjust down by one
        // expect: the insertion of additional GateItem under "Act"

        String queueableId = '1234567';

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__QueueableId' => queueableId,
            '__SequenceName' => 'test',
            '__Position' => 1,
            '__ChunkTotal' => 1,
            '__Chunk' => 1
        };

        List<Message__c> messages = new List<Message__c> ();
        integer i = 1;
        while(i <= count) {
            Map<String,Object> event = inputEvent.clone();
            event.put('c__data' , 'x'+i);
            if (i <= insertIntoMessageCount) {
                String status = (i == insertIntoMessageCount) ? 'Started' : 'Completed';
                messages.add(new Message__c(Event__c = json.serialize(event), Status__c = status));
            }

            i++;
        }
        insert messages;

        // Act
        ApexClassModel.BaseProcess process = new GateByJob();
        List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);

        // Assemble
        Integer actualSize = actualOutputEvents.size();

        // Assert
        Integer expectedSize = 1;
        System.assertEquals(expectedSize , actualSize);

        // Assemble
        Map<String,Object> actualOutputEvent = actualOutputEvents[0];
        String actualQueueableId = (String)inputEvent.get('__QueueableId' );

        // Assert
        String expectedQueueableId = queueableId;
        System.assertEquals(expectedQueueableId , actualQueueableId );
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
        Map<String,Object> actualCommonParameters = GateByJob.getCommonParameters(gateItems);

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
        Map<String,Object> actualCommonParameters = GateByJob.getCommonParameters(gateItems);

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
        Map<String,Object> actualCommonParameters = GateByJob.getCommonParameters(gateItems);

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
            '__x' => 'v1',
            'esb__x' => 'v2',
            'balls' => 'v3'
        };

        // Act
        Map<String,Object> actualParameters =  GateByJob.cleanParameters(parameters);

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
    
    
    static testmethod void callingIsReleaseReturnsExpectedExpected01() {
        // Arrange :
        String queueableId = '12345';
        Integer chunkTotal = 1;
        Integer chunk = 1;

        Message__c message = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"__QueueableId":"'+queueableId+'"}');
        insert message;

        // Act :
        Boolean actualIsRelease = GateByJob.isRelease(queueableId, chunkTotal, chunk);

        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }
  
    
    static testmethod void callingIsReleaseReturnsExpectedExpected02() {
        // Arrange :
        String queueableId = '12345';
        Integer chunkTotal = 2;      // not the last
        Integer chunk = 1;

        Message__c message1 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"__QueueableId":"'+queueableId+'"}');
        insert message1;
        Message__c message2 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"__QueueableId":"'+queueableId+'"}');
        insert message2;

        // Act :
        Boolean actualIsRelease = GateByJob.isRelease(queueableId, chunkTotal, chunk);

        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }
    
    static testmethod void callingIsReleaseReturnsExpectedExpected03() {
        // Arrange :
        String queueableId = '12345';
        Integer chunkTotal = 1;
        Integer chunk = 1;

        Message__c message1 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"__QueueableId":"'+queueableId+'"}');
        insert message1;
        Message__c message2 = new Message__c(Exception__c = null, Status__c = 'Buffered', Event__c = '{"__QueueableId":"'+queueableId+'"}');
        insert message2;

        // Act :
        Boolean actualIsRelease = GateByJob.isRelease(queueableId, chunkTotal, chunk);

        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected04() {
        // Arrange :
        String queueableId = '12345';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c message1 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"__QueueableId":"'+queueableId+'"}');
        insert message1;
        Message__c message2 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"__QueueableId":"'+queueableId+'"}');
        insert message2;
        Message__c message3 = new Message__c(Exception__c = 'Error', Status__c = 'Started', Event__c = '{"__QueueableId":"'+queueableId+'"}');
        insert message3; // this doent count as has an Exception
        
        // Act :
        Boolean actualIsRelease = GateByJob.isRelease(queueableId, chunkTotal, chunk);

        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }
    
}