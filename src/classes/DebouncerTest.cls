@isTest
private class DebouncerTest{

private static testMethod void canDetermineConfigurable () {
    //arrange processes
    Process__c debouncerProcess = Processes.generateOne(Debouncer.class);
    
    //act
    String actualConfiguration = debouncerProcess.Configurable__c;
    
    // Assert
    String expectedConfiguration = Schema.SobjectType.DebouncerConfiguration__c.Name;
    System.assertEquals(expectedConfiguration, actualConfiguration);
}

private static testMethod void callingDebounceReturnsTrueWhenNoInstanceRecordWithKey() {
    //arrange
    Integer hours = 10;
    DebouncerConfiguration__c configuration = new DebouncerConfiguration__c( MinimumHoursBetween__c = hours );
    insert configuration;
    
    Integer minimumHours = 10;
    String key = '1234';
    DateTime currentStamp = System.now();
    
    List<Debouncer__c> debouncers = new List<Debouncer__c>(); // 0 instance records
    
    //act
    Boolean actualRelease = Debouncer.debounce(currentStamp, key, minimumHours, debouncers, configuration.Id);
    
    
    // Assert
    Boolean expectedRelease = true;
    System.assertEquals( expectedRelease, actualRelease );
}
    
    
private static testMethod void callingDebounceReturnsTrueWhenInstanceRecordFoundWithKeyAndOlderEnough() {
    //arrange
    Integer minimumHours = 10;
    DebouncerConfiguration__c configuration = new DebouncerConfiguration__c( MinimumHoursBetween__c = minimumHours );
    insert configuration;
    
    Integer extraHours = 5;
    String key = '1234';
    DateTime currentStamp = System.now();
    DateTime veryOldLastFiredDate =currentStamp.AddHours( -1 * minimumHours ).addHours(-1 * extraHours);
    
    List<Debouncer__c> debouncers = new List<Debouncer__c>(); // 0 instance records
    Debouncer__c debouncer1 = new Debouncer__c(
        DebouncerConfiguration__c = configuration.Id,
        Key__c = key ,
        LastFiredDate__c = veryOldLastFiredDate
    );
    insert debouncer1;
    
    debouncers.add(debouncer1);
    update debouncers;
    
    //act
    Boolean actualRelease = Debouncer.debounce(currentStamp, key, minimumHours, debouncers, configuration.Id);
    
    
    // Assert
    Boolean expectedRelease = true;
    System.assertEquals( expectedRelease, actualRelease );
}

private static testMethod void callingDebounceReturnsFalseWhenInstanceRecordFoundWithKeyAndVeryRecent() {
    //arrange
    Integer minimumHours = 10;
    DebouncerConfiguration__c configuration = new DebouncerConfiguration__c( MinimumHoursBetween__c = minimumHours );
    insert configuration;
    
    Integer extraHours = 5;
    String key = '1234';
    DateTime currentStamp = System.now();
    DateTime veryRecentLastFiredDate =currentStamp.AddHours( -1 * minimumHours ).addHours( extraHours);
    
    List<Debouncer__c> debouncers = new List<Debouncer__c>(); // 0 instance records
    Debouncer__c debouncer1 = new Debouncer__c(
        DebouncerConfiguration__c = configuration.Id,
        Key__c = key ,
        LastFiredDate__c = veryRecentLastFiredDate
    );
    insert debouncer1;
    
    debouncers.add(debouncer1);
    update debouncers;
    
    //act
    Boolean actualRelease = Debouncer.debounce(currentStamp, key, minimumHours, debouncers, configuration.Id);
    
    
    // Assert
    Boolean expectedRelease = false;
    System.assertEquals( expectedRelease, actualRelease );
}
    
    
private static testMethod void callingDeleteOldDebouncersDeletesExpectedDebouncers() {
    //arrange
    DebouncerConfiguration__c configuration = new DebouncerConfiguration__c();
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
    
    Debouncer__c debouncer01 = new Debouncer__c(
    DebouncerConfiguration__c = configuration.Id,
    Key__c = key ,
    LastFiredDate__c = lastFiredDate01
    );
    insert debouncer01;
    
    Debouncer__c debouncer02 = new Debouncer__c(
    DebouncerConfiguration__c = configuration.Id,
    Key__c = key ,
    LastFiredDate__c = lastFiredDate02
    );
    insert debouncer02;
    
    Debouncer__c debouncer03 = new Debouncer__c(
    DebouncerConfiguration__c = configuration.Id,
    Key__c = key ,
    LastFiredDate__c = lastFiredDate03
    );
    insert debouncer03;
    
    //act
    Debouncer.deleteOldDebouncers( currentStamp, minimumHours, bufferHours ) ;
    
    //assemble
    Map<Id,Debouncer__c> debouncerIdToDebouncer = new Map<Id,Debouncer__c> ( [SELECT Id, Name FROM Debouncer__c] );
    
    // Assert
    System.Assert( debouncerIdToDebouncer.keySet().contains(debouncer01.Id) );
    System.Assert( debouncerIdToDebouncer.keySet().contains(debouncer02.Id) );
    System.Assert( !debouncerIdToDebouncer.keySet().contains(debouncer03.Id) );
}

private static testMethod void callingInvokeWhenZeroDebuncersReleasesParameters() {
    //arrange
    Account account = new Account (Name = 'Crow' );
    insert account;
    String accountId = account.Id;
    
    Process__c DebouncerProcess = Processes.generateOne(Debouncer.class);
    
    Chain__c chain = new Chain__c(Name = 'DebouncerChain');
    insert chain;
    
    ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, DebouncerProcess.Id);
    
    DebouncerConfiguration__c configuration = [
        SELECT Id, MinimumHoursBetween__c
        FROM DebouncerConfiguration__c
    ];
    
    Integer minimumHours = 10;
    configuration.MinimumHoursBetween__c = minimumHours;
    update configuration;
    
    
    Map<String,Object> parameters = new Map<String,Object>{
        'eda__configuration' => [SELECT id FROM DebouncerConfiguration__c].Id,
        'id' => accountId
    };
    
    //act
    Debouncer plugin = new Debouncer();
    Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
    List<Map<String,Object>> results = Utility.convert(result);
    
    // Assert
    Integer expectedSize = 1; //-- no pre-existing debouncers , so expect one
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
    
    Process__c DebouncerProcess = Processes.generateOne(Debouncer.class);
    
    Chain__c chain = new Chain__c(Name = 'DebouncerChain');
    insert chain;
    
    ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, DebouncerProcess.Id);
    
    DebouncerConfiguration__c configuration = [
    SELECT Id, MinimumHoursBetween__c
    FROM DebouncerConfiguration__c
    ];
    
    Debouncer__c d = new Debouncer__c(
        DebouncerConfiguration__c = configuration.Id,
        Key__c = key ,
        LastFiredDate__c = lastFiredDate
    );
    insert d;
    
    
    configuration.MinimumHoursBetween__c = minimumHours ;
    update configuration;
    
    
    Map<String,Object> parameters = new Map<String,Object>{
        'eda__configuration' => [SELECT id FROM DebouncerConfiguration__c].Id,
        'id' => key
    };
    
    //act
    Debouncer plugin = new Debouncer();
    Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
    List<Map<String,Object>> results = Utility.convert(result);
    
    // Assert
    Integer expectedSize = 1; //-- one pre-existing debouncer outside window , so expect one
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
    
    Process__c DebouncerProcess = Processes.generateOne(Debouncer.class);
    
    Chain__c chain = new Chain__c(Name = 'DebouncerChain');
    insert chain;
    
    ChainStep__c chainStep = ChainSteps.generateOne(chain.Id, DebouncerProcess.Id);
    
    DebouncerConfiguration__c configuration = [
        SELECT Id, MinimumHoursBetween__c
        FROM DebouncerConfiguration__c
    ];
    
    Debouncer__c d = new Debouncer__c(
        DebouncerConfiguration__c = configuration.Id,
        Key__c = key ,
        LastFiredDate__c = lastFiredDate
    );
    insert d;
    
    
    configuration.MinimumHoursBetween__c = minimumHours ;
    update configuration;
    
    
    Map<String,Object> parameters = new Map<String,Object>{
        'eda__configuration' => [SELECT id FROM DebouncerConfiguration__c].Id,
        'id' => key
    };
    
    //act
    Debouncer plugin = new Debouncer();
    Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
    List<Map<String,Object>> results = Utility.convert(result);
    
    // Assert
    Integer expectedSize = 0; //-- one pre-existing debouncer inside window , so expect zero
    Integer actualSize = results.size();
    System.assertEquals(expectedSize, actualSize);
    }
}