@IsTest public class ApexClassModelTest {
    
    //@TestVisible private preferred, but Type.forName does not support
    public class DescribeProcess extends ApexClassModel.BaseProcess {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
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

    static testmethod void testEsbFromEsb() {
        //arrange
        ApexClassModel.ESB actual = ApexClassModel.esbFromEsb(DescribeProcess.class);
        
        //act
        DescribeProcessESB expected = (DescribeProcessESB)DescribeProcessESB.class.newInstance();
        
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
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return null;
        }
    }
    
    //@TestVisible private preferred, but Type.forName does not support
    public class DefaultProcessESB extends ApexClassModel.BaseSummary {}
    
    static testmethod void testDefaultValues() {
        //act
        ApexClassModel model = new ApexClassModel(DefaultProcess.class);
        
        //assert
        System.assertEquals('Undescribed', model.esb.Description, 'Wrong Description.');
        System.assertEquals('Untagged', model.esb.Tag, 'Wrong Tag.');
        System.assertEquals(DefaultProcess.class.getName(), model.esb.Name, 'Wrong Name.');
        System.assertEquals('cog', model.esb.Icon, 'Wrong Icon.');
        System.assertEquals('Any', model.esb.Cardinality, 'Wrong Cardinality.');
        System.assertEquals(1, model.esb.Limits, 'Wrong Limits.');
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
    
}