public class ChainStepExtensionConfigure {
	
	private ChainStep__c chainStep;
	
	public ChainStepExtensionConfigure(ApexPages.StandardController controller) {
		controller.addFields(new List<String>{
			SObjectType.ChainStep__c.fields.Configuration__c.Name,
			SObjectType.ChainStep__c.fields.Process__c.Name
		});
		this.chainStep = (ChainStep__c)controller.getRecord();
	}
	
	public PageReference initConfig() {
		if (null == this.chainStep.Configuration__c) {
			//find process
			Process__c process = [SELECT ApexClass__c FROM Process__c WHERE Id = :chainStep.Process__c];
			
			//instantiate
			Type reflector = Type.forName(process.ApexClass__c);
			Configurable configurable = (Configurable)reflector.newInstance();
			
			//write configuration instance
			SObject configuration = (SObject)configurable.configure();
			insert configuration;
			
			//update chain step with id
			this.chainStep.Configuration__c = configuration.Id;
			update this.chainStep;
		}
		
		//return config
		return new PageReference('/' + this.chainStep.Configuration__c + '/e?retURL=' + chainStep.Id);
	}
	
}