public class ProcessExtensionCustomize {
	
	private ApexPages.StandardController controller;
	
	public ProcessExtensionCustomize(ApexPages.StandardController controller) {
		if (!Test.isRunningTest()) controller.addFields(new List<String>{SObjectType.Process__c.fields.ApexClass__c.Name});
		this.controller = controller;
	}
	
	public System.PageReference initCustom() {
		try {
			//customizable processes redirect to setting tab
			Process__c process = (Process__c)this.controller.getRecord();
			Type reflector = Type.forName(process.ApexClass__c);
			Customizable custom = (Customizable)reflector.newInstance();
			SObjectType setting = custom.customize();
			String prefix = setting.getDescribe().getKeyPrefix();
			return new System.PageReference('/' + prefix + '/o');
		} catch (Exception e) {
			//uncustomizable process redirects back to process detail
			Process__c process = (Process__c)this.controller.getRecord();
			return new ApexPages.StandardController(process).view();
		}
	}
	
}