@isTest private class ProcessDiscoverBatchTest {
    
    public class MockApexClassProvider implements ProcessDiscoverBatch.IApexClassProvider {
        private List<ApexClass> apexClasses;
        
        public MockApexClassProvider(List<ApexClass> apexClasses) {
          this.apexClasses = apexClasses; 
        }
        
        public List<ApexClass> getApexClasses() {
            return this.apexClasses;  
        }
    } 
    
    static testMethod void testRecordCreatedForPluginAndStateful() {
        //arrange
        ProcessDiscoverBatch batch = new ProcessDiscoverBatch();
        batch.query = 'SELECT Id, NamespacePrefix, Name FROM ApexClass WHERE Name = \'Terminate\' ORDER BY Name ASC LIMIT 1';
        
        //act
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        List<Process__c> processes = SalesforceObjectSet.listAll(Process__c.SObjectType);
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = processes.size();
        System.assertEquals(expectedCount, actualCount);
        
        String expectedName = 'Terminate';
        String actualName = processes[0].Name;
        System.assert(actualName.contains(expectedName));

        String expectedDescription = 'end of this sequence';
        String actualDescription = processes[0].Description__c;
        System.assert(actualDescription.contains(expectedDescription));
        
        String expectedTag = 'Event Driven Architecture';
        String actualTag = processes[0].Tag__c;
        System.assert(actualDescription.contains(expectedDescription));
    }
    

 
    static testMethod void testImplementsEdaSubclass() {
        // arrange
        Type gate = Type.forName('Gate.Meta');
        Type mark = Type.forName('Mark.Meta');
        Type terminate = Type.forName('Terminate.Meta');
        Type branch = Type.forName('Branch.Meta');
        Type wiretap = Type.forName('Wiretap.Meta');
        Type publish = Type.forName('Publish.Meta');
        Type schedule = Type.forName('Schedule.Meta');
        Type subsequence = Type.forName('Subsequence.Meta');
        Type subscribe = Type.forName('Subscribe.Meta');
        Type scrape = Type.forName('Scrape.Meta');
        Type isChanged = Type.forName('IsChanged.Meta');
        Type isNewData = Type.forName('IsNewData.Meta');
        Type logInitializer = Type.forName('LogInitializer.Meta');
        Type logWriter = Type.forName('LogWriter.Meta');
        
        // act
        Boolean actualGate = (gate != null);
        Boolean actualMark = (mark != null);
        Boolean actualTerminate = (terminate != null);
        Boolean actualBranch = (branch != null);
        Boolean actualWiretap = (wiretap != null);
        Boolean actualPublish = (publish != null) ;
        Boolean actualSchedule = (schedule != null);
        Boolean actualSubsequence = (subsequence != null);
        Boolean actualSubscribe = (subscribe != null);
        Boolean actualScrape = (scrape != null);
        Boolean actualIsChanged = (isChanged != null);
        Boolean actualIsNewData = (isNewData != null);
        Boolean actualLogInitializer = (logInitializer != null);
        Boolean actualLogWriter = (logWriter != null);
        
        // assert
        System.assert(actualSubsequence);
        System.assert(actualBranch);
        System.assert(actualGate);
        System.assert(actualMark);
        System.assert(actualPublish);
        System.assert(actualSchedule);
        System.assert(actualTerminate);
        System.assert(actualSubscribe);
        System.assert(actualWiretap);
        System.assert(actualScrape);
        System.assert(actualIsChanged);
        System.assert(actualIsNewData);
        System.assert(actualLogInitializer);
        System.assert(actualLogWriter);
    }
   
    
    static testMethod void callingGetProcessHealthReturnsOkForProcessWithApexClass() {
        //arrange - 
        String processName = Terminate.class.getName();
        Process__c process =  new Process__c(Name = processName, FullyQualifiedClassName__c = processName);
        insert process;
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        Step__c stepValid = new Step__c(Sequence__c = sequence.Id, Process__c = process.Id, Position__c = 1);
        insert stepValid;
 
        //act - 
        ProcessDiscoverBatch.IApexClassProvider apexClassProvider = new ProcessDiscoverBatch.ApexClassProvider();
        ProcessDiscoverBatch.ProcessHealth processHealth = new ProcessDiscoverBatch.ProcessHealth(apexClassProvider);
        Map<Id, String> processHealthMap = processHealth.getProcessHealth() ;
 
        //assert
        String expectedValid = 'Ok';
        String actualValid = processHealthMap.get(process.Id);
        System.assertEquals(expectedValid, actualValid);
    }

  
    static testMethod void callingGetProcessHealthReturnsDeleteForProcessWithoutApexClassAndNotUsedInAnySequences() {       
        // arrange - 
        String processName = Wiretap.class.getName();
        Process__c process =  new Process__c(Name = processName, FullyQualifiedClassName__c = processName);
        insert process;
        List<ApexClass> apexClasses = new List<ApexClass>{
                //new ApexClass(Name ='Wiretap' ) ,   // implies deleted!
                new ApexClass(Name ='Terminate' )  
            } ;
 

        //act - 
        ProcessDiscoverBatch.IApexClassProvider apexClassProvider = new MockApexClassProvider(apexClasses);
        ProcessDiscoverBatch.ProcessHealth processHealth = new ProcessDiscoverBatch.ProcessHealth(apexClassProvider);
        Map<Id, String> processHealthMap = processHealth.getProcessHealth() ;
        
 
        
        //assert
        String expectedProcess = 'Delete';
        String actualProcess = processHealthMap.get(process.Id);
        System.assertEquals(expectedProcess, actualProcess);      
    
    }

    static testMethod void callingGetProcessHealthReturnsErroForProcessWithoutApexClassAndUsedOneOrMoreSequences() {

         // arrange - 
        String processName = Wiretap.class.getName();
        Process__c process =  new Process__c(Name = processName, FullyQualifiedClassName__c = processName);
        insert process;
        List<ApexClass> apexClasses = new List<ApexClass>{
                //new ApexClass(Name ='Wiretap' ) ,   // implies deleted!
                new ApexClass(Name ='Terminate' )  
            } ;
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        Step__c stepValid = new Step__c(Sequence__c = sequence.Id, Process__c = process.Id, Position__c = 1);
        insert stepValid;     
                
 
        
        //act - 
        ProcessDiscoverBatch.IApexClassProvider apexClassProvider = new MockApexClassProvider(apexClasses);
        ProcessDiscoverBatch.ProcessHealth processHealth = new ProcessDiscoverBatch.ProcessHealth(apexClassProvider);
        Map<Id, String> processHealthMap = processHealth.getProcessHealth() ;
        
        //assert
        String expectedProcess = 'Error - Step with no Apex Class';
        String actualProcess = processHealthMap.get(process.Id);
        System.assertEquals(expectedProcess, actualProcess);      
    }
    
    
    static testMethod void callingDeleteInvalidUnusedProcessesDeletesExpectedProcesses() {
        //arrange - 
        String processNameKeep = Terminate.class.getName();
        Process__c processKeep =  new Process__c(Name = processNameKeep, FullyQualifiedClassName__c = processNameKeep);
        insert processKeep;
        
        String processNameDelete = Wiretap.class.getName();
        Process__c processDelete =  new Process__c(Name = processNameDelete, FullyQualifiedClassName__c = processNameDelete);
        insert processDelete;     

        List<Process__c> processesBefore = SalesforceObjectSet.listAll(Process__c.SObjectType);
        Integer actualProcessesBeforeSize = processesBefore.size();
        Integer expectedProcessesBeforeSize = 2;
        
        Map<Id, String> processHealthMap = new Map<Id, String>{
            processKeep.Id  => 'Ok',
            processDelete.Id => 'Delete'    
        };
 
        //act 
        ProcessDiscoverBatch.deleteInvalidUnusedProcesses(processHealthMap);
 
        //assemble
        List<Process__c> processesAfter = SalesforceObjectSet.listAll(Process__c.SObjectType);
        Integer actualProcessesAfterSize = processesAfter.size();
        Integer expectedProcessesAfterSize = 1;
        
        //assert
        System.assertEquals(expectedProcessesAfterSize, actualProcessesAfterSize);
        System.assertEquals(expectedProcessesBeforeSize, actualProcessesBeforeSize); 
    } 
}