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
                    'herp' => 'derp'
                }
            };
        }
    }
    
    static testmethod void testBaseProcessAggregatesOutputParameters() {
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
    }
}