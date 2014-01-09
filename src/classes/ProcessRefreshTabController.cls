public class ProcessRefreshTabController {
    
    @RemoteAction static public List<Process__c> readProcesses() {
        return [
            SELECT Id, Name, Description__c
            FROM Process__c
            ORDER BY Name ASC
        ];
    }
    
}