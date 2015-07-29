public with sharing class ProcessDescribeController {
    
    public ApexClassModel.ESB Process {public get; private set;}
    
    public ProcessDescribeController() {
        String fqcn = ApexPages.currentPage().getParameters().get('fqcn');
        this.Process = new ApexClassModel(Type.forName(fqcn)).model;
    }
    
}