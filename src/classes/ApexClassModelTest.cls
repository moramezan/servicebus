@IsTest public class ApexClassModelTest {
    
    //@TestVisible private preferred, but Type.forName does not support
    public class DescribeProcess extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return null;
        }
    }
    
    //@TestVisible private preferred, but Type.forName does not support
    public class DescribeProcessESB extends ApexClassModel.BaseSummary {
        String Tag = 'Tag';
        String Name = 'Name';
        String Description = 'Description';
        String Icon = 'Icon';
        Integer Limits = 99;
        String HelpUrl = 'HelpUrl';
        String StepConfig = 'StepConfig';
        String ProcessSetting = 'ProcessSetting';
        String Cardinality = 'Any';
        Map<String,String> Inputs = new Map<String,String>{'herp' => 'derp'};
        Map<String,String> Outputs = new Map<String,String>{'foo' => 'bar'};
    }

    static testmethod void testSummary() {
        //arrange
        ApexClassModel.Summary actual = new ApexClassModel.Summary(DescribeProcess.class);
        
        //act
        DescribeProcessESB expected = new DescribeProcessESB();
        
        //assert
        System.assertEquals(expected.Tag, actual.Tag, 'Wrong Tag.');
        System.assertEquals(expected.Name, actual.Name, 'Wrong Name.');
        System.assertEquals(expected.Description, actual.Description, 'Wrong Description.');
        System.assertEquals(expected.Icon, actual.Icon, 'Wrong Icon.');
        System.assertEquals(expected.Limits, actual.Limits, 'Wrong Limits.');
        System.assertEquals(expected.HelpUrl, actual.HelpUrl, 'Wrong HelpUrl.');
        System.assertEquals(expected.StepConfig, actual.StepConfig, 'Wrong StepConfig.');
        System.assertEquals(expected.ProcessSetting, actual.ProcessSetting, 'Wrong ProcessSetting.');
        System.assertEquals(expected.Cardinality, actual.Cardinality, 'Wrong Cardinality.');
        System.assertEquals(expected.Inputs, actual.Inputs, 'Wrong Inputs.');
        System.assertEquals(expected.Outputs, actual.Outputs, 'Wrong Outputs.');
    }
 
    //@TestVisible private preferred, but Type.forName does not support
    public class DefaultProcess extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return null;
        }
    }
    
    //@TestVisible private preferred, but Type.forName does not support
    public class DefaultProcessESB extends ApexClassModel.BaseSummary {}
    
    static testmethod void testDefaultValues() {
        //act
        ApexClassModel.Summary summary = new ApexClassModel.Summary(DefaultProcess.class);
        
        //assert
        System.assertEquals('Undescribed', summary.Description, 'Wrong Description.');
        System.assertEquals('Untagged', summary.Tag, 'Wrong Tag.');
        System.assertEquals(DefaultProcess.class.getName(), summary.Name, 'Wrong Name.');
        System.assertEquals('cog', summary.Icon, 'Wrong Icon.');
        System.assertEquals('Any', summary.Cardinality, 'Wrong Cardinality.');
        System.assertEquals(1, summary.Limits, 'Wrong Limits.');
    }
    
    static testmethod void testShowSetting() {
        //arrange
        ApexClassModel model = new ApexClassModel(Wiretap.class);
        
        //act
        PageReference redirect = model.showSetting();
        
        //assert
        String expectedUrl = '/' + SObjectType.WiretapSetting__c.KeyPrefix + '/o';
        String actualUrl = redirect.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong URL.');
    }
    
    public class MissingToString {}
    
    static testmethod void testInvokeCalloutFailureWhenMissingToString() {
        //arrange model
        ApexClassModel model = new ApexClassModel(MissingToString.class);
        
        try {
            //act
            model.invokeCallout(new Map<String,Object>());
            System.assert(false, 'Line above should throw exception');
        } catch (Exception e) {
            //assert
            String expectedMessage = MissingToString.class.getName() + ': ESB Process must extend Abstract.ESB';
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
        } catch (Exception e) {
            //assert
            String expectedMessage = MissingToString.class.getName() + ': ESB Process must extend Abstract.ESB';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    public class NullReturnValue extends ApexClassModel.BaseProcess {
        override protected void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {return null;}
    }
    
    static testmethod void testInvokeCalloutSuccessWhenNullReturnValue() {
        //arrange model
        ApexClassModel model = new ApexClassModel(NullReturnValue.class);
        
        //act
        model.invokeCallout(new Map<String,Object>());
        
        //assert
        System.assert(true, 'Got here.');
    }
    
    static testmethod void testInvokeExecuteFailureWhenNullReturnValue() {
        //arrange model
        ApexClassModel model = new ApexClassModel(NullReturnValue.class);
        
        try {
            //act
            model.invokeExecute(new Map<String,Object>());
        } catch (Exception e) {
            //assert
            String expectedMessage = NullReturnValue.class.getName() + ': Return type of an ESB Process must be a List<Map<String,Object>>';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    public class GoodReturnValue extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
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
    
    public class InputProcess extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            String expectedChristmas = '"2015-12-25T13:59:59.000Z"';
            String actualChristmas = '"' + inputEvent.get('christmas') + '"';
            System.assertEquals(expectedChristmas, actualChristmas, 'Wrong cycle.');
            return new List<Map<String,Object>>();
        }
    }
    
    static testmethod void testBaseProcessCyclesInputParameters() {
        //arrange process
        ApexClassModel.BaseProcess impl = new InputProcess();
        
        //arrange input
        Datetime christmas = Datetime.newInstanceGmt(2015, 12, 25, 13, 59, 59);
        Map<String,Object> inputEvent = new Map<String,Object>{'christmas' => christmas};
        
        //assert (inside process)
        impl.test(inputEvent);
    }
    
    public class OutputProcess extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{
                    'foo' => 'baz',
                    'herp' => 'derp',
                    'now' => Datetime.now()
                }
            };
        }
    }
    
    static testmethod void testBaseProcessAggregatesAndCyclesOutputParameters() {
        //arrange process
        ApexClassModel.BaseProcess impl = new OutputProcess();
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'foo' => 'bar'
        };
        
        //act
        List<Map<String,Object>> outputEvents = impl.test(inputEvent);
        
        //assert
        System.assert(outputEvents[0].containsKey('foo'));
        System.assert(outputEvents[0].containsKey('herp'));
        System.assertEquals('baz', (String)outputEvents[0].get('foo'), 'Not overwritten.');
        System.assertEquals('derp', (String)outputEvents[0].get('herp'), 'Not appended.');
        System.assert(outputEvents[0].get('now') instanceof String, 'Wrong now type.');
    }
    
    public class TooManyOutputs extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
            for (Integer i = 0; i < 5123; i++) outputEvents.add(inputEvent);
            return outputEvents;
        }
    }
    
    public class TooManyOutputsESB extends ApexClassModel.BaseSummary {
        Integer Limits = 1;
    }
    
    static testmethod void testTooManyOutputsBlowsUp() {
        //arrange
        ApexClassModel model = new ApexClassModel(TooManyOutputs.class);
        
        try {
            //act
            model.invokeExecute(new Map<String,Object>());
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            String expectedMessage = TooManyOutputs.class.getName() + ': Too many output events: 5123';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    public class TooManyInputs extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return null;
        }
    }
    
    public class TooManyInputsESB extends ApexClassModel.BaseSummary {
        Integer Limits = 2345;
    }
    
    static testmethod void testTooManyInputsCapped() {
        //arrange
        ApexClassModel model = new ApexClassModel(TooManyInputs.class);
        
        //act
        ApexClassModel.Summary summary = new ApexClassModel.Summary(TooManyInputs.class);
        
        //assert
        Integer expectedLimits = 2000;
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits, 'Wrong limits.');
    }
    
    public class TooManyEvents extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            insert new Document(Name = 'Test', FolderId = UserInfo.getUserId());
            List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
            for (Integer i = 0; i < 200; i++) outputEvents.add(new Map<String,Object>{
                'Sequence' => 'Test#1'
            });
            return outputEvents;
        }
    }
    
    public class TooManyEventsESB extends ApexClassModel.BaseSummary {
        Integer Limits = 50; //10000
    }
    
    static testmethod void testTooManyEventsBlowsUp() {
        //arrange messages (39 would be ok, 40 is bad, 41 is bad)
        List<Message__c> inputMessages = new List<Message__c>();
        for (Integer i = 0; i < 41; i++) inputMessages.add(new Message__c(
            Route__c = 'ApexClassModelTest.TooManyEvents',
            Event__c = '{"Process":"ApexClassModelTest.TooManyEvents"}'
        ));
        
        //act (39th guy hits 7840, 40th guy hits 8040, 41st guy hits 8240)
        List<Message__c> outputMessages = new List<Message__c>();
        Broker.impl().execute(inputMessages, outputMessages);
        
        //assert
        String expectedException = null;
        String actualException = inputMessages[38].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');

        expectedException = Broker.UserException.class.getName() + ': ' + TooManyEvents.class.getName() + ': Cannot have more than 8000 events in a single operation. Reduce process Limits or emit fewer events.';
        actualException = inputMessages[39].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');

        expectedException = Broker.UserException.class.getName() + ': ' + TooManyEvents.class.getName() + ': Cannot have more than 8000 events in a single operation. Reduce process Limits or emit fewer events.';
        actualException = inputMessages[40].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
        
        Integer expectedCount = 39;
        Integer actualCount = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        //this guy checks that any side effects are rolled back after the 8000 limit reached
    }
    
    public class SpecialOneShotWithSequenceOutput extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{
                    'Sequence' => 'Test'
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
    
    public class SpecialOneShotWithProcessOutput extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{
                    'Process' => 'Test'
                }
            };
        }
    }
    
    static testmethod void testOneShotOutputsSurviveWhenDestinedForProcess() {
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>();
        
        //act
        ApexClassModel model = new ApexClassModel(SpecialOneShotWithProcessOutput.class);
        List<Map<String,Object>> outputEvents = model.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    public class NormalOneShotWithOutputs extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
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
    
    public class ChainedOneShotWithOutputs extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{
                    'Process' => 'ApexClassOne'
                },
                new Map<String,Object>{
                    'Process' => 'ApexClassTwo'
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
}