global class ChainSorterController {
	
    ApexPages.StandardController controller;
    
    global ChainSorterController(ApexPages.StandardController controller) {
        controller.addFields(new List<String>{'Name'});
        this.controller = controller;
    }
    
    public String getNewChainStepUrl() {
        String data = new System.PageReference('/' + Schema.SObjectType.ChainStep__c.KeyPrefix + '/e').getContent().toString();
        String masterLabel = Schema.SObjectType.ChainStep__c.fields.Chain__c.Label;
        String expr
            = Pattern.quote('<label for="CF') //literal CF
            + '(00N[A-Za-z0-9]{12})' //capture literal 00N followed by exactly 12 alphanumeric characters
            + Pattern.quote('"><span class="requiredMark">*</span>') //literal asterisk thingo
            + Pattern.quote(masterLabel) //the name of the master object as seen by the detail
            + Pattern.quote('</label>') //literal
        ;
        
        Matcher m = Pattern.compile(expr).matcher(data);
        m.find();
        String fieldId = m.group(1);
        
        String absoluteUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/' + Schema.SObjectType.ChainStep__c.KeyPrefix + '/e';
        System.PageReference pr = new System.PageReference(absoluteUrl);
        pr.getParameters().putAll(new Map<String,String>{
            'CF' + fieldId => (String)this.controller.getRecord().get('Name'),
            'CF' + fieldId + '_lkid' => this.controller.getId(),
            'saveURL' => this.controller.view().getUrl()
        });
        return pr.getUrl();
    }
    
    @RemoteAction static global List<ChainStep__c> readChainSteps(Id chainId) {
        return [
            SELECT Id, Name, Chain__c, Sequence__c, Process__r.Name, Process__r.Description__c
            FROM ChainStep__c
            WHERE Chain__c = :chainId
            ORDER BY Sequence__c
        ];
    }
    
    @RemoteAction static global List<ChainStep__c> updateChainSteps(List<ChainStep__c> chainSteps) {
        update chainSteps;
        return chainSteps;
    }
    
    @RemoteAction static global void destroyChainSteps(List<ChainStep__c> stepsToDelete) {
        //first get a handle on the chain whose steps will reorder afterwards
        Id chainId = [
            SELECT Chain__c
            FROM ChainStep__c
            WHERE Id = :stepsToDelete[0].Id
        ].Chain__c;
        
        //delete the intended steps
        delete stepsToDelete;
        
        List<ChainStep__c> stepsToReorder = [
            SELECT Id
            FROM ChainStep__c
            WHERE Chain__c = :chainId
            ORDER BY Sequence__c
        ];
        
        Integer sequence = 1;
        for (ChainStep__c chainStep : stepsToReorder) {
            chainStep.Sequence__c = sequence++;
        }
        
        update stepsToReorder;
    }
    
    @RemoteAction static global String enqueue(Id chainId) {
        Chain__c chain = [SELECT Name FROM Chain__c WHERE Id = :chainId];
        Broker.enqueue(chain.Name, UserInfo.getUserId());
        return chain.Name;
    }
    
}