public class ApexClassSetModel extends ApexDomain.StandardSetModel {
    
    /**
     * Privatize constructor to force use of factory
     */
    private ApexClassSetModel(List<ApexClass> apexClasses) {
        super(apexClasses);
    }
    
    @TestVisible static List<ApexClass> MockClasses;
    
    /**
     * Factory method to locate all ESB processes by
     * attempting to instantiate ESB summary class
     */
    static public ApexClassSetModel discoverProcesses() {
        //select out ALL apex classes
        List<ApexClass> apexClasses = MockClasses != null ? MockClasses : [
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Name != 'ApexClassModel' //don't discover our ESB summary class template ;)
            ORDER BY Name ASC
            LIMIT 10000 //resolves checkmarx Queries_With_No_Where_Or_Limit_Clause
        ];
        
        //prepare list of PROCESS apex classes
        List<ApexClass> processes = new List<ApexClass>();
        
        //bulletproof reflection on each ESB summary class
        for (ApexClass apexClass : apexClasses) try {
            //uses two arguments per #910 to reach out of managed package namespace!
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            
            //fails if compile problem with the class, eg LeadShare when OWD set to public
            if (reflector == null) continue; //failure, class has private visibility
            String apexClassName = reflector.getName();
            
            //fails if there is no ESB summary class
            Type inflector = Type.forName(apexClassName + '.ESB');
            if (inflector != null) processes.add(apexClass);
        } catch (Exception e) {}
        
        //factory
        return new ApexClassSetModel(processes);
    }
    
    /**
     * This returns a list of Apex Class DTOs with the minimum information seen by the user.
     * If a key is needed, we can use the Id, as the name is friendly, not fully qualified.
     * These DTOs would be consumed by the Sequence Builder interface, hiding our secret sauce.
     *
     * [
     *     {
     *         "Id": "01p2400000AaMs1";
     *         "Name": "Gate By Entry Point";
     *         "Description": "Aggregates a collection of messages having the same Entry Point Id.",
     *         "Tag": "Enterprise Service Bus",
     *         "Icon": "arrow_join",
     *         "Cardinality": "Fewer",
     *         "ProcessSetting": null
     *     },
     *     {
     *         "Id": "01p2400000AaMs3";
     *         "Name": "Gate By Job";
     *         "Description": "Aggregates a collection of messages having the same Job Id.",
     *         "Tag": "Enterprise Service Bus",
     *         "Icon": "arrow_join",
     *         "Cardinality": "Fewer",
     *         "ProcessSetting": null
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
            Type inflector = Type.forName(reflector.getName() + '.ESB');
            if (inflector == null) continue;
            
            ApexClassModel.ESB esb = ApexClassModel.esbFromEsb(inflector);
            
            Map<String,Object> dto = new Map<String,Object>{
                'ApexClassName' => reflector.getName(), //TODO per #886 get rid of this!!!
                'Id' => apexClass.Id,
                'Name' => esb.Name,
                'Description' => esb.Description,
                'Tag' => esb.Tag,
                'Icon' => esb.Icon,
                'Cardinality' => esb.Cardinality,
                'ProcessSetting' => esb.ProcessSetting
            };
            
            //attempt to populate the description of the process
            if (esb.Description == null) dto.put('Description', 'Undescribed');
            
            //attempt to populate the tag of the process (with sensible default)
            if (esb.Tag == null) dto.put('Tag', 'Untagged');
            
            //attempt to populate the css class name of the process icon (with sensible default)
            if (esb.Icon == null) dto.put('Icon', 'cog');
            
            //attempt to populate the cardinality of the process
            if (esb.Cardinality == null) dto.put('Cardinality', 'Any');
            
            dtos.add(dto);
        } catch (Exception e) {}
        
        return dtos;
    }
    
}