public with sharing class ProcessExtensionCustomize {
	
	private ApexPages.StandardController controller;
	
	public ProcessExtensionCustomize(ApexPages.StandardController controller) {
		if (!Test.isRunningTest()) controller.addFields(new List<String>{SObjectType.Process__c.fields.Name.Name});
		this.controller = controller;
	}
	
	public System.PageReference initCustom() {
		try {
			//customizable processes redirect to setting tab
			Process__c process = (Process__c)this.controller.getRecord();
			Type reflector = Type.forName(process.Name);
			Process.Plugin plugin = (Process.Plugin)reflector.newInstance(); //get process
			String customizable = (String)Utility.meta(plugin.describe().Description).get('eda__customizable'); //get meta
			SObject setting = (SObject)Type.forName(customizable).newInstance();
			String prefix = setting.getSObjectType().getDescribe().getKeyPrefix();
			return new System.PageReference('/' + prefix + '/o');
		} catch (Exception e) {
			//uncustomizable process redirects back to process detail
			Process__c process = (Process__c)this.controller.getRecord();
			return new ApexPages.StandardController(process).view();
		}
	}
	
}