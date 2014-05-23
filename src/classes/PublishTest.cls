@isTest private class PublishTest {

    static testMethod void canDetermineConfigObject() {
        //arrange processes
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        //act
        String actualConfiguration = publishProcess.ConfigObject__c;
        
        //assert
        String expectedConfiguration = Schema.SObjectType.PublishConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
    
    static testMethod void testSubsequenceDropped() {
        //arrange events
        EventType__c eventType = new EventType__c(Name = 'ready');
        insert eventType;
        
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        
        //arrange publish config
        PublishConfiguration__c pubConfig = new PublishConfiguration__c(
            EventType__c = eventType.Id
        );
        insert pubConfig;
        
        //arrange sequence
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        
        Step__c subscribeStep = StepObjectSet.generateOne(target.Id, subscribeProcess.Id);
        
        //arrange subscribe config
        Database.update(new SubscribeConfiguration__c(
            Id = subscribeStep.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        Map<String,Object> parameters = new Map<String,Object>{
            'eda_ConfigObjectId' => pubConfig.Id,
            'eda_SubsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Publish plugin = new Publish();
        List<Map<String,Object>> parametersList = EdaUtility.convert(plugin.invoke(new Process.PluginRequest(parameters)));
        
        //should return one for sub, one for passthru
        Integer expectedSize = 2;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        //first one is for subscriber
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[0].get('eda_SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
        
        //second one is original/passthru
        expectedIds = new List<Id>{'000000000000000AAA'};
        actualIds = (List<Object>)parametersList[1].get('eda_SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testMethod void testUnconfiguredPublishProcessThrowsException() {
        //arrange processes
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepObjectSet.generateOne(sequence.Id, publishProcess.Id);
        
        PublishConfiguration__c config = new PublishConfiguration__c();
        insert config;
        
        Publish plugin = new Publish();
        Map<String,Object> parameters = new Map<String,Object>{'eda_SequenceName' => 'TestSequence', 'eda_Position' => 1, 'eda_ConfigObjectId' => config.Id};
        Process.PluginRequest request = new Process.PluginRequest(parameters);
        
        //act
        Boolean thrown = false;
        try {plugin.invoke(request);}
        catch (Publish.PublishException e) {thrown = true;}
        
        //assert
        System.assert(thrown);
    }
    
    static testMethod void testNoSubscribersStillReturnsOneMessage() {
        //arrange processes
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepObjectSet.generateOne(sequence.Id, publishProcess.Id);
        Database.update(new PublishConfiguration__c(
            Id = step.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        String data = '{"eda_SequenceName":"TestSequence","eda_Position":1,"eda_ConfigObjectId":"' + step.ConfigurationId__c + '"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        Publish plugin = new Publish();
        
        //act
        Process.PluginResult results = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> parametersList = EdaUtility.convert(results);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        Integer expectedData = data.length();
        Integer actualData = System.Json.serialize(parametersList[0]).length();
        System.assertEquals(expectedData, actualData);
    }
    
    static testMethod void testSubscribersAffectParametersListReturned() {
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        //arrange publish sequences and steps
        Sequence__c publisher = new Sequence__c(Name = 'Publisher');
        insert publisher;
        
        Step__c publisherStep = StepObjectSet.generateOne(publisher.Id, publishProcess.Id);
        Database.update(new PublishConfiguration__c(
            Id = publisherStep.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        //arrange subscribe sequences and steps
        Sequence__c subscriber1 = new Sequence__c(Name = 'Subscriber1');
        insert subscriber1;
        
        Step__c subscriber1step = StepObjectSet.generateOne(subscriber1.Id, subscribeProcess.Id);
        Database.update(new SubscribeConfiguration__c(
            Id = subscriber1step.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        Sequence__c subscriber2 = new Sequence__c(Name = 'Subscriber2');
        insert subscriber2;
        
        Step__c subscriber2step = StepObjectSet.generateOne(subscriber2.Id, subscribeProcess.Id);
        Database.update(new SubscribeConfiguration__c(
            Id = subscriber2step.ConfigurationId__c,
            EventType__c = eventType.Id
        ));
        
        //arrange
        Map<String,Object> parameters = new Map<String,Object>{'eda_SequenceName' => 'Publisher', 'eda_Position' => 1, 'eda_ConfigObjectId' => publisherStep.ConfigurationId__c};
        
        //act
        Publish plugin = new Publish();
        Process.PluginResult results = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> parametersList = EdaUtility.convert(results);
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
}