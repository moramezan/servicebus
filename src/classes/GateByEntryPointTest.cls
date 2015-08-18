@IsTest public class GateByEntryPointTest {


   static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(GateByEntryPoint.class);
        
        //assert
        Integer expectedLimits = 50; //max sync limit
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }


   static testmethod void withinSystemLimits() {
        // Arrange
        Integer count =  3 ;
        Integer insertIntoMessageCount = count;
        Integer insertIntoGateItemCount = count - 1;  // Adjust down by one
        // expect: the insertion of additional GateItem under "Act"

        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';

        Map<String,Object> inputEvent = new Map<String,Object> {
            'EntryPointUuid' => entryPointUuid,
            'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1
        };

        List<Message__c> messages = new List<Message__c> ();
        integer k = 1;
        while(k <= count) {
            Map<String,Object> event = inputEvent.clone();
            event.put('c__data' , 'x'+k);
            if (k <= insertIntoMessageCount) {
                String status = (k == insertIntoMessageCount) ? 'Started' : 'Completed';
                messages.add(new Message__c(Event__c = json.serialize(event), Status__c = status));
            }

            k++;
        }
        insert messages;
        
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(GateByEntryPoint.class);
        
        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.BaseProcess process = new GateByEntryPoint();
            List<Map<String,Object>> outputs = process.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }


    static testmethod void callingIsReleaseThrowsExpectedException01() {
        // Arrange :
        Map<String,Object> inputEvent = new Map<String,Object> {
            //'EntryPointUuid' => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
            'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1
        };
                    
        Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = process.test(inputEvent);
        } catch (Exception e) {
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
            //'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1
        };
                    
        Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = process.test(inputEvent);
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
            'EntryPointUuid' => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
            'Route' => 'Test#1',
            //'Range' => 1,
            'Chunk' => 1
        };
                    
        Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = process.test(inputEvent);
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
            'EntryPointUuid' => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
            'Route' => 'Test#1',
            'Range' => 1
            //'Chunk' => 1
        };
                    
        Boolean actualFlag = false;
        try {
            ApexClassModel.BaseProcess process = new GateByEntryPoint();
            List<Map<String,Object>> actualOutputEvents = process.test(inputEvent);
        } catch (Exception e) {
            actualFlag = e.getMessage().contains('missing mandatory Chunk');
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

        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';

        Map<String,Object> inputEvent = new Map<String,Object> {
            'EntryPointUuid' => entryPointUuid,
            'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1
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
        ApexClassModel.BaseProcess process = new GateByEntryPoint();
        List<Map<String,Object>> actualOutputEvents = process.test(inputEvent);

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

        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';

        Map<String,Object> inputEvent = new Map<String,Object> {
            'EntryPointUuid' => entryPointUuid,
            'Route' => 'Test#1',
            'Range' => 1,
            'Chunk' => 1
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
        ApexClassModel.BaseProcess process = new GateByEntryPoint();
        List<Map<String,Object>> actualOutputEvents = process.test(inputEvent);

        // Assemble
        Integer actualSize = actualOutputEvents.size();

        // Assert
        Integer expectedSize = 1;
        System.assertEquals(expectedSize , actualSize);

        // Assemble
        Map<String,Object> actualOutputEvent = actualOutputEvents[0];
        String actualEntryPointUuid = (String)inputEvent.get('EntryPointUuid' );

        // Assert
        String expectEdentryPointUuid = entryPointUuid;
        System.assertEquals(expectEdentryPointUuid , actualEntryPointUuid );
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
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 1;
        Integer chunk = 1;

        Message__c message = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"EntryPointUuid":"'+entryPointUuid+'"}');
        insert message;

        // Act :
        Boolean actualIsRelease = GateByEntryPoint.isRelease(entryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }
  
    
    static testmethod void callingIsReleaseReturnsExpectedExpected02() {
        // Arrange :
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 2;      // not the last
        Integer chunk = 1;

        Message__c message1 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"EntryPointUuid":"'+entryPointUuid+'"}');
        insert message1;
        Message__c message2 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"EntryPointUuid":"'+entryPointUuid+'"}');
        insert message2;

        // Act :
        Boolean actualIsRelease = GateByEntryPoint.isRelease(entryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }
    
    static testmethod void callingIsReleaseReturnsExpectedExpected03() {
        // Arrange :
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 1;
        Integer chunk = 1;

        Message__c message1 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"EntryPointUuid":"'+entryPointUuid+'"}');
        insert message1;
        Message__c message2 = new Message__c(Exception__c = null, Status__c = 'Buffered', Event__c = '{"EntryPointUuid":"'+entryPointUuid+'"}');
        insert message2;

        // Act :
        Boolean actualIsRelease = GateByEntryPoint.isRelease(entryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedIsRelease = false;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }

    static testmethod void callingIsReleaseReturnsExpectedExpected04() {
        // Arrange :
        String entryPointUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
        Integer chunkTotal = 2;
        Integer chunk = 2;

        Message__c message1 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"EntryPointUuid":"'+entryPointUuid+'"}');
        insert message1;
        Message__c message2 = new Message__c(Exception__c = null, Status__c = 'Started', Event__c = '{"EntryPointUuid":"'+entryPointUuid+'"}');
        insert message2;
        Message__c message3 = new Message__c(Exception__c = 'Error', Status__c = 'Started', Event__c = '{"EntryPointUuid":"'+entryPointUuid+'"}');
        insert message3; // this doent count as has an Exception
        
        // Act :
        Boolean actualIsRelease = GateByEntryPoint.isRelease(entryPointUuid, chunkTotal, chunk);

        // Assemble :
        // n/a
        
        // Assert :
        Boolean expectedIsRelease = true;
        System.assertEquals(expectedIsRelease , actualIsRelease);
    }
    
}