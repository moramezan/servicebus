@IsTest public class GateByEntryPointTest {

    static testmethod void callingInvokeMainReturnsZeroOutputEventsWhenPersistedCountNotEqOneWithStartedStatus() {
        // Arrange
        Decimal count =  3 ;
        Decimal insertIntoMessageCount = count;

        String entryPointUuid = '1234567';

        Map<String,Object> inputEvent = new Map<String,Object> {
            'esb__EntryPointUuid' => entryPointUuid
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
        ProcessModel.BaseProcess process = new GateByEntryPoint();
        List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);

        // Assemble
        Decimal actualSize = actualOutputEvents.size();

        // Assert
        Decimal expectedSize = 0;
        System.assertEquals(expectedSize , actualSize);
    }



    static testmethod void callingInvokeMainReturnsOneOutputEventWhenPersistedCountEqOneWithStartedStatus() {
        // Arrange
        Decimal count =  3 ;
        Decimal insertIntoMessageCount = count;
        Decimal insertIntoGateItemCount = count - 1;  // Adjust down by one
        // expect: the insertion of additional GateItem under "Act"

        String entryPointUuid = '1234567';

        Map<String,Object> inputEvent = new Map<String,Object> {
            'esb__EntryPointUuid' => entryPointUuid
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
        ProcessModel.BaseProcess process = new GateByEntryPoint();
        List<Map<String,Object>> actualOutputEvents = process.execute(inputEvent);

        // Assemble
        Decimal actualSize = actualOutputEvents.size();

        // Assert
        Decimal expectedSize = 1;
        System.assertEquals(expectedSize , actualSize);

        // Assemble
        Map<String,Object> actualOutputEvent = actualOutputEvents[0];
        String actualEntryPointUuid = (String)inputEvent.get('esb__EntryPointUuid' );

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
        Decimal actualSize = actualCommonParameters.keySet().size();

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
}