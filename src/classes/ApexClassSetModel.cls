public class ApexClassSetModel extends ApexDomain.StandardSetModel {
    
    /**
     * Model not allowed to make assumptions about
     * the fields he is constructed with. Id only.
     */
    public ApexClassSetModel(List<ApexClass> apexClasses) {
        super(apexClasses);
    }
    
    /**
     * Attempts to instantiate Service.Summary classes and
     * reduces the working record set to valid ones.
     */
    static public ApexClassSetModel discoverServices(Set<Id> apexClassIds) {
        List<ApexClass> apexClasses = [
            SELECT Id, NamespacePrefix, Name, ApiVersion, Status
            FROM ApexClass
            WHERE Id IN :apexClassIds
        ];
        
        //prepare list of SERVICE apex classes
        List<ApexClass> services = new List<ApexClass>();
        
        //bulletproof reflection on each Service.Summary class
        for (ApexClass apexClass : apexClasses) try {
            //uses two arguments per #910 to reach out of managed package namespace!
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            
            //fails if compile problem with the class, eg LeadShare when OWD set to public
            if (reflector == null) continue; //failure, class has private visibility
            String apexClassName = reflector.getName();
            
            //fails if there is no Service.Summary class
            Type inflector = Type.forName(apexClassName + '.Summary');
            
            //we DONT enter each namespace, just assume ok
            if (inflector != null) services.add(apexClass);
        } catch (Exception e) {}
        
        return new ApexClassSetModel(services);
    }
    
    public List<ApexClassModel.Summary> toSummaries() {
        List<ApexClass> apexClasses = [
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Id IN :this.keySet()
        ];
        
        //bulletproof list of summaries
        List<ApexClassModel.Summary> summaries = new List<ApexClassModel.Summary>();
        for (ApexClass apexClass : apexClasses) try {
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            ApexClassModel.Summary summary = new ApexClassModel.Summary(reflector);
            summaries.add(summary);
        } catch (Exception e) {}
        
        return summaries;
    }
    
    /**
     * This returns a list of Apex Class DTOs with the minimum information seen by the user.
     * If a key is needed, we can use the Id, as the name is friendly, not fully qualified.
     * These DTOs would be consumed by the Sequence Builder interface, hiding our secret sauce.
     *
     * [
     *     {
     *         "Id": "01p000000000000AAA";
     *         "Name": "Aggregate By Entry Point";
     *         "Description": "Aggregates a collection of messages having the same Entry Point Id.",
     *         "Tag": "Service Bus",
     *         "Icon": "arrow_join",
     *         "Cardinality": "Fewer",
     *         "ServiceSetting": null
     *     },
     *     {
     *         "Id": "01p000000000000AAA";
     *         "Name": "Aggregate By Job";
     *         "Description": "Aggregates a collection of messages having the same Job Id.",
     *         "Tag": "Service Bus",
     *         "Icon": "arrow_join",
     *         "Cardinality": "Fewer",
     *         "ServiceSetting": null
     *     }
     * ]
     */
    public List<Map<String,Object>> toDtos() {
        //prepare list of DTO
        List<Map<String,Object>> dtos = new List<Map<String,Object>>();
        
        //bulletproof assembly of each one
        List<ApexClass> apexClasses = this.Records;
        for (ApexClass apexClass : apexClasses) try {
            //uses two arguments per #910 to reach out of managed package namespace!
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            Type inflector = Type.forName(reflector.getName() + '.Summary');
            if (inflector == null) continue;
            
            ApexClassModel.Summary summary = new ApexClassModel.Summary(reflector);
            
            Map<String,Object> dto = new Map<String,Object>{
                'Id' => apexClass.Id,
                'Label' => summary.Label,
                'Description' => summary.Description,
                'Tag' => summary.Tag,
                'Icon' => summary.Icon,
                'Cardinality' => summary.Cardinality,
                'StepConfig' => summary.StepConfig,
                'ServiceSetting' => summary.ServiceSetting
            };
            
            dtos.add(dto);
        } catch (Exception e) {}
        
        return dtos;
    }
    
}