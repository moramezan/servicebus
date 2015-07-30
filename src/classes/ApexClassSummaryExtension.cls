public with sharing class ApexClassSummaryExtension {
    
    public ApexClassModel.ESB Process {public get; private set;}
    
    private ApexPages.StandardController controller;
    
    public ApexClassSummaryExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        String fqcn = ApexPages.currentPage().getParameters().get('fqcn');
        this.Process = new ApexClassModel(Type.forName(fqcn)).model;
    }
    
}