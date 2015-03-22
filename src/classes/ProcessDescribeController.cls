public with sharing class ProcessDescribeController {
    
    public Process__c process {public get; private set;}
    public ProcessModel.ESB ESB {public get; private set;}
    
    public ProcessDescribeController() {
        String fqn = ApexPages.currentPage().getParameters().get('fqn');
        
        this.Process = [
            SELECT Id, Name, Tag__c, Icon__c, Description__c, FullyQualifiedClassName__c
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :fqn
        ];
        
        Type innerClass = Type.forName(fqn + '.' + 'ESB');
        if (innerClass == null) innerClass = Type.forName(fqn + 'ESB'); //#828
        this.ESB = (ProcessModel.ESB)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessModel.ESB.class);
    }
    
}