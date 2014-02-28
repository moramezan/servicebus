@isTest  //-- no view of org data
private  class GateTest {

    static testMethod void testProcessIsDescribed() {
        Jump jump = new Jump();
        System.assertNotEquals(null, jump.describe().Name);
        System.assertNotEquals(null, jump.describe().Description);
        System.assertNotEquals(null, jump.describe().Tag);
    }
    
    static testMethod void callingExecuteReturnsExpectedParametersCollectionWhenGateItemsCountEqCount() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        Decimal count =  3 ;

        GateGroup__c gateGroup =  new GateGroup__c() ;
        insert gateGroup;
        Id gateGroupId = gateGroup.Id;

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_sequenceName' => sequenceName,
            'eda_position' => position,
            'eda_gateGroupId' => gateGroupId,
            'eda_count' => count,
            'data' => data
        };

        List<GateItem__c> gateItems = new List<GateItem__c> ();
        integer i = 1;
        while(i <= (count - 1)) // Adjust down by one (to allow the nth one inserted by execute() to equate with value in count)
        {
            Map<String,Object> n = parameters.clone();
            n.put('data' , 'x'+i);
            GateItem__c gateItem = new GateItem__c(
                GateGroup__c = gateGroupId,
                Parameters__c = json.serializePretty(n)
            );
            gateItems.add(gateItem);
            i++;
        }
        insert gateItems;

        Decimal expectedSize = 1;
        Id expectedGateGroupId = gateGroupId;
        Integer expectedGateItemsSize = (Integer) count;

        // Act
        Gate gate = new Gate();
        Process.PluginResult results = gate.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualOutParametersList = EdaUtility.convert(results);

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        Id actualGateGroupId = null;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualGateGroupId = (Id) parameters.get('Id' );
        }
        integer actualGateItemsSize = [SELECT Id FROM GateItem__c].size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(actualGateGroupId , actualGateGroupId );
        System.assertEquals(expectedGateItemsSize , actualGateItemsSize );
    }
    
    
    static testMethod void callingExecuteReturnsExpectedParametersCollectionWhenGateItemsCountNotEqCount() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';
        Decimal count = 3 ;


        GateGroup__c gateGroup = new GateGroup__c() ;
        insert gateGroup;
        Id gateGroupId = gateGroup.Id;

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_sequenceName' => sequenceName,
            'eda_position' => position,
            'eda_gateGroupId' => gateGroupId,
            'eda_count' => count,
            'data' => data
        };

        List<GateItem__c> gateItems = new List<GateItem__c> ();
        integer i = 1;
        while(i <= (count - 2)) {// Adjust down by TWO ( one inserted by execute() will NOT  equate with value in count)
            Map<String,Object> n = parameters.clone();
            n.put('data' , 'x'+i);
            GateItem__c gateItem = new GateItem__c(
                GateGroup__c = gateGroupId ,
                Parameters__c = json.serializePretty(n)
            );
            gateItems.add(gateItem);
            i++;
        }
        insert gateItems;

        Decimal expectedSize = 0;
        Integer expectedGateItemsSize = (Integer) ( count - 1) ;

        // Act
        Gate gate = new Gate();
        Process.PluginResult results = gate.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualOutParametersList = EdaUtility.convert(results);

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        integer actualGateItemsSize = [SELECT Id FROM GateItem__c].size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedGateItemsSize , actualGateItemsSize );
    }
}