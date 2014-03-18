@isTest
private class IsNewDataTest{

private static testMethod void canDetermineConfigurable () {
    //arrange processes
    Process__c IsNewDataProcess = Processes.generateOne(IsNewData.class);
    
    //act
    String actualConfiguration = IsNewDataProcess.Configurable__c;
    
    // Assert
    String expectedConfiguration = Schema.SobjectType.IsNewDataConfiguration__c.Name;
    System.assertEquals(expectedConfiguration, actualConfiguration);
}

private static testMethod void callingIsNewDataeturnsTrueWhenNoInstanceRecordWithKey() {
    //arrange
    Integer hours = 10;
    IsNewDataConfiguration__c configuration = new IsNewDataConfiguration__c( MinimumHoursBetween__c = hours );
    insert configuration;
    
    Integer minimumHours = 10;
    String key = '1234';
    DateTime currentStamp = System.now();
    
    List<IsNewDataInstance__c> IsNewDatas = new List<IsNewDataInstance__c>(); // 0 instance records
    
    //act
    Boolean actualRelease = IsNewData.debounce(currentStamp, key, minimumHours, IsNewDatas, configuration.Id);
    
    
    // Assert
    Boolean expectedRelease = true;
    System.assertEquals( expectedRelease, actualRelease );
}
    
    
private static testMethod void callingIsNewDataeturnsTrueWhenInstanceRecordFoundWithKeyAndOlderEnough() {
    //arrange
    Integer minimumHours = 10;
    IsNewDataConfiguration__c configuration = new IsNewDataConfiguration__c( MinimumHoursBetween__c = minimumHours );
    insert configuration;
    
    Integer extraHours = 5;
    String key = '1234';
    DateTime currentStamp = System.now();
    DateTime veryOldLastFiredDate =currentStamp.AddHours( -1 * minimumHours ).addHours(-1 * extraHours);
    
    List<IsNewDataInstance__c> IsNewDatas = new List<IsNewDataInstance__c>(); // 0 instance records
    IsNewDataInstance__c IsNewData1 = new IsNewDataInstance__c(
        IsNewDataConfiguration__c = configuration.Id,
        Key__c = key ,
        LastFiredDate__c = veryOldLastFiredDate
    );
    insert IsNewData1;
    
    IsNewDatas.add(IsNewData1);
    update IsNewDatas;
    
    //act
    Boolean actualRelease = IsNewData.debounce(currentStamp, key, minimumHours, IsNewDatas, configuration.Id);
    
    
    // Assert
    Boolean expectedRelease = true;
    System.assertEquals( expectedRelease, actualRelease );
}

private static testMethod void callingIsNewDataeturnsFalseWhenInstanceRecordFoundWithKeyAndVeryRecent() {
    //arrange
    Integer minimumHours = 10;
    IsNewDataConfiguration__c configuration = new IsNewDataConfiguration__c( MinimumHoursBetween__c = minimumHours );
    insert configuration;
    
    Integer extraHours = 5;
    String key = '1234';
    DateTime currentStamp = System.now();
    DateTime veryRecentLastFiredDate =currentStamp.AddHours( -1 * minimumHours ).addHours( extraHours);
    
    List<IsNewDataInstance__c> IsNewDatas = new List<IsNewDataInstance__c>(); // 0 instance records
    IsNewDataInstance__c IsNewData1 = new IsNewDataInstance__c(
        IsNewDataConfiguration__c = configuration.Id,
        Key__c = key ,
        LastFiredDate__c = veryRecentLastFiredDate
    );
    insert IsNewData1;
    
    IsNewDatas.add(IsNewData1);
    update IsNewDatas;
    
    //act
    Boolean actualRelease = IsNewData.debounce(currentStamp, key, minimumHours, IsNewDatas, configuration.Id);
    
    
    // Assert
    Boolean expectedRelease = false;
    System.assertEquals( expectedRelease, actualRelease );
}
    
    
private static testMethod void callingDeleteOldIsNewDatasDeletesExpectedIsNewDatas() {
    //arrange
    IsNewDataConfiguration__c configuration = new IsNewDataConfiguration__c();
    insert configuration;
    
    String key = '1234';
    DateTime currentStamp = System.Now();
    Integer minimumHours = 10;
    Integer bufferHours = 3;
    Integer persistDurationInHours = 6;
    //+-----[NEW]
    //---- now --------------
    //---- very recent ------
    DateTime lastFiredDate01 = currentStamp.addHours( -1 * (minimumHours-4) );
    //--- less recent -------
    DateTime lastFiredDate02 = currentStamp.addHours( -1 * (minimumHours-2) );
    //---- minimumHours
    //--- bufferHours
    //---- very old ---------
    DateTime lastFiredDate03 = currentStamp.addHours( -1 * (minimumHours + bufferHours + 2) );
    //+-----[OLD]
    
    IsNewDataInstance__c IsNewData01 = new IsNewDataInstance__c(
    IsNewDataConfiguration__c = configuration.Id,
    Key__c = key ,
    LastFiredDate__c = lastFiredDate01
    );
    insert IsNewData01;
    
    IsNewDataInstance__c IsNewData02 = new IsNewDataInstance__c(
    IsNewDataConfiguration__c = configuration.Id,
    Key__c = key ,
    LastFiredDate__c = lastFiredDate02
    );
    insert IsNewData02;
    
    IsNewDataInstance__c IsNewData03 = new IsNewDataInstance__c(
    IsNewDataConfiguration__c = configuration.Id,
    Key__c = key ,
    LastFiredDate__c = lastFiredDate03
    );
    insert IsNewData03;
    
    //act
    IsNewData.deleteOldIsNewDatas( currentStamp, minimumHours, bufferHours ) ;
    
    //assemble
    Map<Id,IsNewDataInstance__c> IsNewDataIdToIsNewData = new Map<Id,IsNewDataInstance__c> ( [SELECT Id, Name FROM IsNewDataInstance__c] );
    
    // Assert
    System.Assert( IsNewDataIdToIsNewData.keySet().contains(IsNewData01.Id) );
    System.Assert( IsNewDataIdToIsNewData.keySet().contains(IsNewData02.Id) );
    System.Assert( !IsNewDataIdToIsNewData.keySet().contains(IsNewData03.Id) );
}

private static testMethod void callingInvokeWhenZeroDebuncersReleasesParameters() {
    //arrange
    Account account = new Account (Name = 'Crow' );
    insert account;
    String accountId = account.Id;
    
    Process__c IsNewDataProcess = Processes.generateOne(IsNewData.class);
    
    Sequence__c sequence = new Sequence__c(Name = 'IsNewDataSequence');
    insert sequence;
    
    Step__c step = Steps.generateOne(sequence.Id, IsNewDataProcess.Id);
    
    IsNewDataConfiguration__c configuration = [
        SELECT Id, MinimumHoursBetween__c
        FROM IsNewDataConfiguration__c
    ];
    
    Integer minimumHours = 10;
    configuration.MinimumHoursBetween__c = minimumHours;
    update configuration;
    
    
    Map<String,Object> parameters = new Map<String,Object>{
        'eda_configuration' => [SELECT id FROM IsNewDataConfiguration__c].Id,
        'Id' => accountId
    };
    
    //act
    IsNewData plugin = new IsNewData();
    Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
    List<Map<String,Object>> results = EdaUtility.convert(result);
    
    // Assert
    Integer expectedSize = 1; //-- no pre-existing IsNewDatas , so expect one
    Integer actualSize = results.size();
    System.assertEquals(expectedSize, actualSize);
}

private static testMethod void callingInvokeWhenZeroDebuncersReleasesMessageForOutsideMinimumWindow() {
    //arrange
    Account account = new Account (Name = 'Crow' );
    insert account;
    String key = account.Id;
    Integer minimumHours = 10;
    Integer extraOutSideWindowHours = 5;
    DateTime lastFiredDate = System.Now().addHours( -1 * ( minimumHours + extraOutSideWindowHours ) );
    
    Process__c IsNewDataProcess = Processes.generateOne(IsNewData.class);
    
    Sequence__c sequence = new Sequence__c(Name = 'IsNewDataSequence');
    insert sequence;
    
    Step__c step = Steps.generateOne(sequence.Id, IsNewDataProcess.Id);
    
    IsNewDataConfiguration__c configuration = [
    SELECT Id, MinimumHoursBetween__c
    FROM IsNewDataConfiguration__c
    ];
    
    IsNewDataInstance__c d = new IsNewDataInstance__c(
        IsNewDataConfiguration__c = configuration.Id,
        Key__c = key ,
        LastFiredDate__c = lastFiredDate
    );
    insert d;
    
    
    configuration.MinimumHoursBetween__c = minimumHours ;
    update configuration;
    
    
    Map<String,Object> parameters = new Map<String,Object>{
        'eda_configuration' => [SELECT id FROM IsNewDataConfiguration__c].Id,
        'Id' => key
    };
    
    //act
    IsNewData plugin = new IsNewData();
    Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
    List<Map<String,Object>> results = EdaUtility.convert(result);
    
    // Assert
    Integer expectedSize = 1; //-- one pre-existing IsNewData outside window , so expect one
    Integer actualSize = results.size();
    System.assertEquals(expectedSize, actualSize);
}

private static testMethod void callingInvokeWhenZeroDebuncersSwallowsMessageForInsideMinimumWindow() {
    //arrange
    Account account = new Account (Name = 'Crow' );
    insert account;
    String key = account.Id;
    Integer minimumHours = 10;
    Integer extraInSideWindowHours = 5;
    DateTime lastFiredDate = System.Now().addHours( -1 * ( minimumHours - extraInSideWindowHours ) );
    
    Process__c IsNewDataProcess = Processes.generateOne(IsNewData.class);
    
    Sequence__c sequence = new Sequence__c(Name = 'IsNewDataSequence');
    insert sequence;
    
    Step__c step = Steps.generateOne(sequence.Id, IsNewDataProcess.Id);
    
    IsNewDataConfiguration__c configuration = [
        SELECT Id, MinimumHoursBetween__c
        FROM IsNewDataConfiguration__c
    ];
    
    IsNewDataInstance__c d = new IsNewDataInstance__c(
        IsNewDataConfiguration__c = configuration.Id,
        Key__c = key ,
        LastFiredDate__c = lastFiredDate
    );
    insert d;
    
    
    configuration.MinimumHoursBetween__c = minimumHours ;
    update configuration;
    
    
    Map<String,Object> parameters = new Map<String,Object>{
        'eda_configuration' => [SELECT id FROM IsNewDataConfiguration__c].Id,
        'Id' => key
    };
    
    //act
    IsNewData plugin = new IsNewData();
    Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
    List<Map<String,Object>> results = EdaUtility.convert(result);
    
    // Assert
    Integer expectedSize = 0; //-- one pre-existing IsNewData inside window , so expect zero
    Integer actualSize = results.size();
    System.assertEquals(expectedSize, actualSize);
    }

}