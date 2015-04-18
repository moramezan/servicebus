public with sharing class ProcessDescribeController {
    
    public ProcessModel Process {public get; private set;}
    
    public ProcessDescribeController() {
        String fqcn = ApexPages.currentPage().getParameters().get('fqcn');
        this.Process = ProcessModel.fromFqcn(fqcn);
    }
    
}