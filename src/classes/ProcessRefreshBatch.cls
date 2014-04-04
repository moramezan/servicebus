public with sharing class ProcessRefreshBatch implements Database.Batchable<SObject> {
    
    @testVisible private String query = 'SELECT Id, NamespacePrefix, Name FROM ApexClass ORDER BY Name ASC';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext context, List<ApexClass> scope) {
        List<Process__c> edaProcesses = new List<Process__c>();
        for (ApexClass apexClass : scope) {
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            try {
                Process__c edaProcess = ProcessSet.fromType(reflector);
                edaProcesses.add(edaProcess);
            } catch (Exception e) {
                //fuckup happened, probably
                //callout from constructor
            }
        }
        //will not duplicate existing processes
        upsert edaProcesses FullyQualifiedClassName__c;
    }
    
    public void finish(Database.BatchableContext context) {
        ProcessRefreshBatch.IApexClassProvider apexClassProvider = new ProcessRefreshBatch.ApexClassProvider();
        ProcessRefreshBatch.ProcessHealth processHealth = new ProcessRefreshBatch.ProcessHealth(apexClassProvider);
        deleteInvalidUnusedProcesses(processHealth.getProcessHealth());
    }

    public static void deleteInvalidUnusedProcesses(Map<Id,String> processIdToHealth) {
        Set<Id> processIds = new Set<Id>();
        for (Id processId : processIdToHealth.keySet()) {
            if (processIdToHealth.get(processId) == 'Delete') {
                processIds.Add(processId);
            }
        }
        
        delete [SELECT Id FROM Process__c WHERE Id IN :processIds];
    }
    

    public interface IApexClassProvider {
        List<ApexClass> getApexClasses();
    }
    
    public class ApexClassProvider implements IApexClassProvider {
        public List<ApexClass> getApexClasses() {
            return SalesforceObjectSet.listAll(ApexClass.SObjectType);
        }
    } 
    
    public class ProcessHealth {
        private IApexClassProvider apexClassProvider;
        
        public ProcessHealth (IApexClassProvider apexClassProvider) {
        	this.apexClassProvider = apexClassProvider;   
        }

        public  Map<Id,String> getProcessHealth() {
            // obtain set of fully qualified apex class names
            List<ApexClass> apexClasses = apexClassProvider.getApexClasses();
            Set<String> fullyQualifiedClassNames = new Set<String>(); 
            for (ApexClass apexClass : apexClasses ) {
                String namespacePrefix = String.IsBlank(apexClass.NamespacePrefix)  ? '' : apexClass.NamespacePrefix + '.';
                fullyQualifiedClassNames.add(namespacePrefix  + apexClass.Name );  
            }
            
            // obtain a list of process Ids used in sequences
            Set<Id> usedProcessIds = new Set<Id>();
            List<Step__c> allSteps = SalesforceObjectSet.listAll(Step__c.SObjectType);
            for (Step__c step : allSteps) {
                if (step.Process__c != null) {
                    usedProcessIds.add(step.Process__c);    
                }
            }
    
            Map<Id,String> processIdToHealth = new  Map<Id,String>();
            List<Process__c> allProcesses = SalesforceObjectSet.listAll(Process__c.SObjectType);
            for (Process__c process : allProcesses) {
                Boolean hasApexClass = fullyQualifiedClassNames.contains(process.FullyQualifiedClassName__c);
                Boolean hasStep  = usedProcessIds.contains(process.Id);
                String health = 'Ok';
                if (!hasApexClass) {
                    health = 'Delete';
                    if (hasStep) {
                        health = 'Error - Step with no Apex Class';
                    }
                }   
                processIdToHealth.put(process.Id, health);
            }
    
            return processIdToHealth;
        }
    }    
}