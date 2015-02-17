@IsTest private class ProcessDiscoverBatchTest {
    
    public class MockApexClassProvider implements ProcessDiscoverBatch.IApexClassProvider {
        private List<ApexClass> apexClasses;
        
        public MockApexClassProvider(List<ApexClass> apexClasses) {
          this.apexClasses = apexClasses; 
        }
        
        public List<ApexClass> getApexClasses() {
            return this.apexClasses;  
        }
    } 
    
    /*static testmethod void testRecordCreatedForProcessAndStateful() {
        //arrange
        ProcessDiscoverBatch.classes = [
            SELECT Id, Name, NamespacePrefix
            FROM ApexClass
            ORDER BY Name ASC
        ];
        ProcessDiscoverBatch batch = new ProcessDiscoverBatch();
        
        //act
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        List<Process__c> processes = SalesforceObjectSet.listAll(Process__c.SObjectType);
        
        //assert
        Integer expectedCount = 10;
        Integer actualCount = processes.size();
        System.assert(actualCount > expectedCount, 'Should be about ten processes.');
        
        //assemble
        String actualDescription;
        String actualTag;
        for (Process__c process : processes) {
            if (process.Name ==  Terminate.class.getName()) {
                actualDescription = process.Description__c;
                actualTag = process.Tag__c;
            }
        }
        
        //assert
        String expectedDescription = 'end of this sequence';
        System.assert(actualDescription.contains(expectedDescription));
        String expectedTag = 'Enterprise Service Bus';
        System.assert(actualDescription.contains(expectedDescription));
    }*/

 
    static testmethod void testImplementsEsbSubclass() {
        // arrange
        Type gate = Type.forName('Gate.ESB');
        Type mark = Type.forName('Mark.ESB');
        Type terminate = Type.forName('Terminate.ESB');
        Type branch = Type.forName('Branch.ESB');
        Type wiretap = Type.forName('Wiretap.ESB');
        Type publish = Type.forName('Publish.ESB');
        Type schedule = Type.forName('Schedule.ESB');
        Type subsequence = Type.forName('Subsequence.ESB');
        Type subscribe = Type.forName('Subscribe.ESB');
        Type auditInitializer = Type.forName('AuditInitializer.ESB');
        Type auditWriter = Type.forName('AuditWriter.ESB');
        
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
        Boolean actualAuditInitializer = (auditInitializer != null);
        Boolean actualAuditWriter = (auditWriter != null);
        
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
        System.assert(actualAuditInitializer);
        System.assert(actualAuditWriter);
    }
   
    
    static testmethod void callingGetProcessHealthReturnsOkForProcessWithApexClass() {
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

  
    static testmethod void callingGetProcessHealthReturnsDeleteForProcessWithoutApexClassAndNotUsedInAnySequences() {       
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

    static testmethod void callingGetProcessHealthReturnsErroForProcessWithoutApexClassAndUsedOneOrMoreSequences() {

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
    
    
    static testmethod void callingDeleteInvalidUnusedProcessesDeletesExpectedProcesses() {
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

    static testmethod void getQueryLocatorReturnsExpectedIterable() {
        //arrange
        //n/a
        
        //act
        Database.QueryLocator actualQueryLocator = ProcessDiscoverBatch.getQueryLocator(); 
        
        //assemble
        Set<String> actualApexClassNames = new Set<String>();
        Database.QueryLocatorIterator actualIterator =  actualQueryLocator.iterator();
        while (actualIterator.hasNext()) {
            ApexClass apexClass =  (ApexClass)actualIterator.next();
            actualApexClassNames.add(apexClass.Name);
        }
        
        //assert
        system.debug(json.serialize(actualApexClassNames));
        system.assert(true,actualApexClassNames.Contains(WireTap.class.getName()));
        system.assert(true,actualApexClassNames.Contains(Publish.class.getName()));
        system.assert(true,!actualApexClassNames.Contains(ProcessDiscoverBatch.class.getName()));   
    }  
    
}