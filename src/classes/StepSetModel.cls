public class StepSetModel extends ApexDomain.StandardSetModel {
    
    /**
     * Model not allowed to make assumptions about
     * the fields he is constructed with. Id only.
     */
    public StepSetModel(List<Step__c> steps) {
        super(steps);
    }
    
    /**
     * Find the steps from any sequence
     */
    static public StepSetModel forSequence(String sequenceName) {
        List<Step__c> steps = [
            SELECT Id
            FROM Step__c
            WHERE SequenceName__c = :sequenceName
            ORDER BY Position__c ASC
        ];
        
        return new StepSetModel(steps);
    }
    
    /**
     * This returns a list of Step DTOs with the minimum information seen by the user.
     * If a key is needed, we can use the Name, which serves as the unique routing key.
     * These DTOs would be consumed by the Sequence Builder interface, hiding our secret sauce.
     *
     * [
     *     {
     *         "Name": "Wiretaps#1",
     *         "ConfigId": null,
     *         "ConfigName": null,
     *         "ApexClassId": "01p2400000AaMt4",
     *         "ApexClassName": "Wiretap"
     *         "Position": 1.0,
     *     },
     *     {
     *         "Name": "Wiretaps#2",
     *         "ConfigId": null,
     *         "ConfigName": null,
     *         "ApexClassId": "01p2400000AaMsy",
     *         "ApexClassName": "Terminate"
     *         "Position": 2.0,
     *     }
     * ]
     */
    public List<Map<String,Object>> toDtos() {
        //re-query needed fields
        List<Step__c> steps = [
            SELECT Id, Name, ConfigId__c, ConfigName__c, ApexClassId__c, ApexClassName__c, Position__c
            FROM Step__c
            WHERE Id IN :this.keySet()
            ORDER BY Position__c ASC
        ];
        
        //prepare list of DTO
        List<Map<String,Object>> dtos = new List<Map<String,Object>>();
        
        for (Step__c step : steps) {
            Map<String,Object> dto = new Map<String,Object>{
                'Name' => step.Name,
                'ConfigId' => step.ConfigId__c,
                'ConfigName' => step.ConfigName__c,
                'ApexClassId' => step.ApexClassId__c,
                'ApexClassName' => step.ApexClassName__c,
                'Position' => step.Position__c.intValue()
            };
            
            dtos.add(dto);
        }
        
        return dtos;
    }
}