@IsTest //-- no view of org data
private class WiretapTest {
    
    static testmethod void hasTheCorrectLimits() {
        //arrange 
        Type actualType = Wiretap.class;
        Type outerClass = Type.forName(actualType.getName());  
        Type innerClass = Type.forName(outerClass.getName() + '.' + 'Meta'); 
        ProcessObject.Meta meta = (ProcessObject.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.Meta.class);
        
        //act 
        Integer actualLimits = meta.Limits;  

        //assemble
        actualLimits = (actualLimits == null) ? 1 : actualLimits; 

        //assert
        Integer expectedLimits = 9;
        System.assertEquals(expectedLimits, actualLimits);
    }

    static testmethod void callingInvokeWillNOTThrowExpectedWhenUserIdOnProcessSettingNOTSet() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer step = 1;
        String data = 'data';

       //--NOT-DEFINED insert new WiretapSetting__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            'esb_SequenceName' => sequenceName,
            'esb_Step' => step,
            'data' => data
        };
        

   

        // Act
        Boolean actualFlagException = false;
        try {
            Type reflector = Wiretap.class;
            List<Map<String,Object>> results = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;
        } catch (Exception e) {
           actualFlagException = true;
        }
        
 
        // Assert
        Boolean expectedFlagException = false;
        System.assertEquals(expectedFlagException , actualFlagException );
    }
   
    static testmethod void callingExecuteReturnsExpectedParametersCollectionWhenDefinedMetaProcessSettingSet() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer step = 1;
        String data = 'data';

        insert new WiretapSetting__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            'esb_SequenceName' => sequenceName,
            'esb_Step' => step,
            'data' => data
        };
        

        Integer expectedSize = 1;

        // Act
        Type reflector = Wiretap.class;
        List<Map<String,Object>> actualParametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

        // prepare
        Integer actualSize = actualParametersList.size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
}