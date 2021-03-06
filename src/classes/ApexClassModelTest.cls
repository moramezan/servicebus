@IsTest class ApexClassModelTest {
    
    //@TestVisible private preferred, but Type.forName does not support
    public class DescribeService extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return null;
        }
    }
    
    //@TestVisible private preferred, but Type.forName does not support
    public class DescribeServiceDefinition extends ApexClassModel.Definition {
        String Tag = 'Tag';
        String Label = 'Name';
        String Description = 'Description';
        String Icon = 'Icon';
        Integer Chunks = 99;
        String HelpUrl = 'HelpUrl';
        String StepConfig = 'StepConfig';
        String ServiceConfig = 'ServiceConfig';
        String Cardinality = 'Any';
        Map<String,String> Inputs = new Map<String,String>{'herp' => 'derp'};
        Map<String,String> Outputs = new Map<String,String>{'foo' => 'bar'};
    }

    static testmethod void testDefinition() {
        //arrange
        ApexClassModel.Definition actual = new ApexClassModel.Definition(DescribeService.class);
        
        //act
        DescribeServiceDefinition expected = new DescribeServiceDefinition();
        
        //assert
        System.assertEquals(expected.Tag, actual.Tag, 'Wrong Tag.');
        System.assertEquals(expected.Label, actual.Label, 'Wrong Name.');
        System.assertEquals(expected.Description, actual.Description, 'Wrong Description.');
        System.assertEquals(expected.Icon, actual.Icon, 'Wrong Icon.');
        System.assertEquals(expected.Chunks, actual.Chunks, 'Wrong Chunks.');
        System.assertEquals(expected.HelpUrl, actual.HelpUrl, 'Wrong HelpUrl.');
        System.assertEquals(expected.StepConfig, actual.StepConfig, 'Wrong StepConfig.');
        System.assertEquals(expected.ServiceConfig, actual.ServiceConfig, 'Wrong ServiceConfig.');
        System.assertEquals(expected.Cardinality, actual.Cardinality, 'Wrong Cardinality.');
        System.assertEquals(expected.Inputs, actual.Inputs, 'Wrong Inputs.');
        System.assertEquals(expected.Outputs, actual.Outputs, 'Wrong Outputs.');
    }
 
    //@TestVisible private preferred, but Type.forName does not support
    public class DefaultService extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return null;
        }
    }
    
    //@TestVisible private preferred, but Type.forName does not support
    public class DefaultServiceDefinition extends ApexClassModel.Definition {}
    
    static testmethod void testDefaultValues() {
        //act
        ApexClassModel.Definition definition = new ApexClassModel.Definition(DefaultService.class);
        
        //assert
        System.assertEquals('Undescribed', definition.Description, 'Wrong Description.');
        System.assertEquals('Untagged', definition.Tag, 'Wrong Tag.');
        System.assertEquals(DefaultService.class.getName(), definition.Label, 'Wrong Name.');
        System.assertEquals('cog', definition.Icon, 'Wrong Icon.');
        System.assertEquals('Any', definition.Cardinality, 'Wrong Cardinality.');
        System.assertEquals(1, definition.Chunks, 'Wrong Chunks.');
    }
    
    static testmethod void testDescribeServiceDefinition() {
        //arrange
        ApexClassModel model = new ApexClassModel(DebugService.class);
        
        //act
        DescribeSObjectResult result = model.describeServiceConfig();
        
        //assert
        String expectedName = DebugServiceConfig__c.class.getName();
        String actualName = result.getName();
        System.assertEquals(expectedName, actualName, 'Wrong Name.');
    }
    
    public class MissingToString {}
    
    static testmethod void testInvokeCalloutFailureWhenMissingToString() {
        //arrange model
        ApexClassModel model = new ApexClassModel(MissingToString.class);

        try {
            //act
            model.invokeCallout(new Map<String,Object>());
            System.assert(false, 'Line above should throw exception');
        } catch (Broker.ServiceException e) {
            //assert
            String expectedMessage = MissingToString.class.getName() + ': Service must extend Abstract.Service';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    static testmethod void testInvokeExecuteFailureWhenMissingToString() {
        //arrange model
        ApexClassModel model = new ApexClassModel(MissingToString.class);

        try {
            //act
            model.invokeExecute(new Map<String,Object>());
            System.assert(false, 'Line above should throw exception');
        } catch (Broker.ServiceException e) {
            //assert
            String expectedMessage = MissingToString.class.getName() + ': Service must extend Abstract.Service';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    public class NullReturnValue extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {return null;}
    }
    
    static testmethod void testInvokeCalloutSuccessWhenNullReturnValue() {
        //arrange model
        ApexClassModel model = new ApexClassModel(NullReturnValue.class);
        
        //act
        model.invokeCallout(new Map<String,Object>());
        
        //assert
        System.assert(true, 'Got here.');
    }

    //TODO #1069
    /*static testmethod void testInvokeExecuteFailureWhenNullReturnValue() {
        //arrange model
        ApexClassModel model = new ApexClassModel(NullReturnValue.class);

        try {
            //act
            model.invokeExecute(new Map<String,Object>());
        } catch (Broker.ServiceException e) {
            //assert
            String expectedMessage = NullReturnValue.class.getName() + ': Return type of a Service execute method must be a List<Map<String,Object>>';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }*/
    
    public class GoodReturnValue extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>();
        }
    }
    
    static testmethod void testInvokeCalloutSuccessWhenGoodReturnValue() {
        //arrange model
        ApexClassModel model = new ApexClassModel(GoodReturnValue.class);
        
        //act
        model.invokeCallout(new Map<String,Object>());
        
        //assert
        System.assert(true, 'Got here.');
    }
    
    static testmethod void testInvokeExecuteSuccessWhenGoodReturnValue() {
        //arrange model
        ApexClassModel model = new ApexClassModel(GoodReturnValue.class);
        
        //act
        List<Map<String,Object>> outputEvents = model.invokeExecute(new Map<String,Object>());
        
        //assert
        System.assertNotEquals(null, outputEvents, 'Wrong output events.');
    }
    
    public class InputService extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            String expectedChristmas = '"2015-12-25T13:59:59.000Z"';
            String actualChristmas = '"' + inputEvent.get('christmas') + '"';
            System.assertEquals(expectedChristmas, actualChristmas, 'Wrong cycle.');
            return new List<Map<String,Object>>();
        }
    }
    
    static testmethod void testServiceCyclesInputParameters() {
        //arrange service
        ApexClassModel.Service impl = new InputService();
        
        //arrange input
        Datetime christmas = Datetime.newInstanceGmt(2015, 12, 25, 13, 59, 59);
        Map<String,Object> inputEvent = new Map<String,Object>{'christmas' => christmas};
        
        //assert (inside service)
        List<Map<String,Object>> outputEvents = new ApexClassModel(InputService.class).invokeExecute(inputEvent);
        
        System.assert(outputEvents.isEmpty(), 'Wrong output.');
    }
    
    public class OutputService extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{
                    'foo' => 'baz',
                    'herp' => 'derp',
                    'now' => Datetime.now()
                }
            };
        }
    }
    
    static testmethod void testServiceAggregatesAndCyclesOutputParameters() {
        //arrange service
        ApexClassModel impl = new ApexClassModel(OutputService.class);
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'foo' => 'bar'
        };
        
        //act
        List<Map<String,Object>> outputEvents = impl.invokeExecute(inputEvent);
        
        //assert
        System.assert(outputEvents[0].containsKey('foo'));
        System.assert(outputEvents[0].containsKey('herp'));
        System.assertEquals('baz', (String)outputEvents[0].get('foo'), 'Not overwritten.');
        System.assertEquals('derp', (String)outputEvents[0].get('herp'), 'Not appended.');
        System.assert(outputEvents[0].get('now') instanceof String, 'Wrong now type.');
    }
    
    public class TooManyOutputs extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
            for (Integer i = 0; i < 5123; i++) outputEvents.add(inputEvent);
            return outputEvents;
        }
    }
    
    public class TooManyOutputsDefinition extends ApexClassModel.Definition {
        Integer Chunks = 1;
    }
    
    static testmethod void testTooManyOutputsBlowsUp() {
        //arrange
        ApexClassModel model = new ApexClassModel(TooManyOutputs.class);
        
        try {
            //act
            model.invokeExecute(new Map<String,Object>());
            System.assert(false, 'Line above should throw exception.');
        } catch (Broker.ServiceException e) {
            String expectedMessage = TooManyOutputs.class.getName() + ': Too many output events: 5123';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    public class TooManyInputs extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return null;
        }
    }
    
    public class TooManyInputsDefinition extends ApexClassModel.Definition {
        Integer Chunks = 2345;
    }
    
    static testmethod void testTooManyInputsCapped() {
        //arrange
        ApexClassModel model = new ApexClassModel(TooManyInputs.class);
        
        //act
        ApexClassModel.Definition definition = new ApexClassModel.Definition(TooManyInputs.class);
        
        //assert
        Integer expectedChunks = 100; //#955 possibly 2000, but headspace
        Integer actualChunks = definition.Chunks;
        System.assertEquals(expectedChunks, actualChunks, 'Wrong chunks.');
    }
    
    //TooManyEvents
    public class TME extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            insert new Document(Name = 'Test', FolderId = UserInfo.getUserId());
            List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
            for (Integer i = 0; i < 200; i++) outputEvents.add(new Map<String,Object>{
                'Route' => '1#Test#1' //dont swallow one shot
            });
            return outputEvents;
        }
    }
    
    public class TMEDefinition extends ApexClassModel.Definition {
        Integer Chunks = 50; //50 * 200 = 10000
    }
    
    static testmethod void testTooManyEventsBlowsUp() {
        //arrange messages (9 would be ok, 10 is bad, 11 is bad) //#955 formerly (39 would be ok, 40 is bad, 41 is bad)
        List<Message__c> inputMessages = new List<Message__c>();
        for (Integer i = 0; i < 11; i++) inputMessages.add(new Message__c(
            Event__c = Json.serialize(new Map<String,Object>{'Route' => TME.class.getName()})
        ));
        
        //act (9/10 guy hits 1810, 10/10 guy hits 2010, 11/11 would hit 2211) //#955 formerly (39/40 guy hits 7840, 40/40 guy hits 8040, 41/411 would hits 8241) sum of inputs + outputs
        insert inputMessages;
        new MessageSetModel(inputMessages).mark('0000'); //populates 'Range' event parameter
        List<Message__c> outputMessages = new MessageSetModel(inputMessages).execute(null);
        
        //assert
        String expectedException = null;
        String actualException = inputMessages[8].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');

        expectedException = Broker.ServiceException.class.getName() + ': ' + TME.class.getName() + ': Cannot have more than 2000 events in a single operation. Reduce service Chunks or emit fewer events.'; //#955 possibly 8000, but headspace
        actualException = inputMessages[9].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');

        expectedException = Broker.ServiceException.class.getName() + ': ' + TME.class.getName() + ': Cannot have more than 2000 events in a single operation. Reduce service Chunks or emit fewer events.'; //#955 possibly 8000, but headspace
        actualException = inputMessages[10].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
        
        Integer expectedCount = 9;
        Integer actualCount = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        //this guy checks that any side effects are rolled back after our limit was reached
    }
    
    public class SpecialOneShotWithSequenceOutput extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{
                    'Route' => '1#Test#1'
                }
            };
        }
    }
    
    static testmethod void testOneShotOutputsSurviveWhenDestinedForSequence() {
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>();
        
        //act
        ApexClassModel model = new ApexClassModel(SpecialOneShotWithSequenceOutput.class);
        List<Map<String,Object>> outputEvents = model.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    public class SpecialOneShotWithServiceOutput extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{
                    'Route' => DebugService.class.getName()
                }
            };
        }
    }
    
    static testmethod void testOneShotOutputsSurviveWhenDestinedForService() {
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>();
        
        //act
        ApexClassModel model = new ApexClassModel(SpecialOneShotWithServiceOutput.class);
        List<Map<String,Object>> outputEvents = model.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    public class NormalOneShotWithOutputs extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>()
            };
        }
    }
    
    static testmethod void testOneShotSwallowsOutputsNormally() {
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => NormalOneShotWithOutputs.class.getName()
        };
        
        //act (note the aggregated output parameters)
        ApexClassModel model = new ApexClassModel(NormalOneShotWithOutputs.class);
        List<Map<String,Object>> outputEvents = model.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 0;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    public class ChainedOneShotWithOutputs extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{
                    'Route' => DebugService.class.getName()
                },
                new Map<String,Object>{
                    'Route' => TerminateService.class.getName()
                }
            };
        }
    }
    
    static testmethod void testOneShotCanCallAnotherOneShot() {
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>();
        
        //act
        ApexClassModel model = new ApexClassModel(ChainedOneShotWithOutputs.class);
        List<Map<String,Object>> outputEvents = model.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    public class ThrowerService extends ApexClassModel.Service {
        override public void callout(Map<String,Object> inputEvent) {
            Integer i = 1 / 0; //System.MathException: Divide by 0
            throw new Broker.ServiceException('Line above should throw exception.');
        }
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            new ApexPages.StandardController(null); //System.NullPointerException: Argument cannot be null
            throw new Broker.ServiceException('Line above should throw exception.');
        }
    }
    
    static testmethod void testCatchableExceptionIsThrown() {
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>();
        ApexClassModel model = new ApexClassModel(ThrowerService.class);
        
        try {
            //act
            model.invokeCallout(inputEvent);
            System.assert(false, 'Line above should throw exception.');
        } catch (MathException e) {
            //assert
            String expectedMessage = 'Divide by 0';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage);
        }
        
        try {
            //act
            model.invokeExecute(inputEvent);
            System.assert(false, 'Line above should throw exception.');
        } catch (NullPointerException e) {
            //assert
            String expectedMessage = 'Argument cannot be null';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage);
        }
    }
}