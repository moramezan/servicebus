public class ApexClassSetModel extends ApexDomain.StandardSetModel {
    
    public class ModelException extends Exception {}
    
    @TestVisible List<ApexClass> ApexClasses;
    
    /**
     * Private constructor enforces
     * use of static factory method.
     */
    @TestVisible ApexClassSetModel(List<ApexClass> apexClasses) {
        super(apexClasses);
        this.ApexClasses = apexClasses;
    }
    
    /**
     * This is basically a server-side confidence that the Apex Classes in the
     * org have changed. Additional or Modified classes will cause the DATE to
     * waver. Deleted classes will cause the COUNT to waver. Any change detected.
     */
    static public String classKey() {
        
        ApexClass apexClass = [
            SELECT LastModifiedDate
            FROM ApexClass
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        
        Integer count = [
            SELECT COUNT()
            FROM ApexClass
            LIMIT 10000 //checkmarx
        ];
        
        //eg ApexClassCache_1447306203000_93
        return 'ApexClassCache' + '_' + apexClass.LastModifiedDate.getTime() + '_' + count;
    }
    
    /**
     * We store the classKey from above in a custom setting
     * which makes it easy (ServerCacheKey != ClientCacheKey) to
     * detect if cache is stale in Sequence Builder and Service Discovery
     */
    static public String cacheKey() {
        
        try {
            Document document = [
                SELECT Description
                FROM Document
                WHERE Name = 'ApexClassCache.bin'
            ];
            
            //class cache key
            return document.Description;
            
        } catch (QueryException e) {
            //nothing cached
            return null;
        }
        
    }
    
    /**
     * Usually after Service Discovery,
     * we persist everything to a Document.
     */
    static public Id saveCache(List<ApexClassModel.Summary> summaries) {
        
        Folder folder = [
            SELECT Id
            FROM Folder
            WHERE DeveloperName = 'ServiceBus'
        ];
        
        String data = Json.serializePretty(summaries);
        
        Document document = new Document(
            Name = 'ApexClassCache.bin',
            Description = classKey(),
            FolderId = folder.Id,
            Body = Blob.valueOf(data)
        );
        
        //WTF DeveloperName = 'ApexClassCacheBin',
        //Cannot save cache: Upsert failed. First exception on row 0; first error: DUPLICATE_DEVELOPER_NAME, This Document Unique Name already exists or has been previously used.  Please choose a different name.: [DeveloperName]
        
        Id documentId = Database.upsert(document, Schema.Document.Name).getId();
        
        return documentId;
    }
    
    /**
     * The Sequence Builder and Services Tab
     * rely on reading data from this cache.
     */
    static public List<ApexClassModel.Summary> loadCache() {
        
        try {
            Document document = [
                SELECT Body
                FROM Document
                WHERE Name = 'ApexClassCache.bin'
            ];
            
            //hydrate cache
            return (List<ApexClassModel.Summary>)Json.deserialize(
                document.Body.toString(),
                List<ApexClassModel.Summary>.class
            );
            
        } catch (QueryException e) {
            //nothing cached
            return new List<ApexClassModel.Summary>();
        }
        
    }
    
    static public ApexClassSetModel fromNamespace(String namespace) {
        return new ApexClassSetModel([
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE NamespacePrefix = :namespace
            AND Name != 'ApexClassModel'
            ORDER BY Name ASC
        ]);
    }
    
    /**
     * #946 by discovering the namespaces one-by-one with Visualforce Remoting
     * we won't hit the 10 namespace limit, and they run in parallel (fast)
     */
    public List<ApexClassModel.Summary> discoverSummaries() {
        
        List<ApexClassModel.Summary> summaries = new List<ApexClassModel.Summary>();
        
        for (ApexClass apexClass : this.ApexClasses) try {
            
            //uses two arguments per #910 to reach out of managed package namespace!
            Type inflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name + '.Summary');
            
            if (inflector == null) {
                //no summary class
                continue;
            }
            
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            ApexClassModel.Summary summary = new ApexClassModel.Summary(reflector);
            summary.Id = apexClass.Id; //gotta provide the id from outside
            summaries.add(summary);
            
        } catch (JsonException e) {
            //fails if compile problem with the class, eg LeadShare when OWD set to public
        }
        
        return summaries;
        
    }
    
    /**
     * This finds candidate namespaces with a few exceptions:
     * for example FinancialForce (thousands of classes)
     * for example BmcServiceDesk (thousands of classes)
     * for example Abstract (thats our base class!)
     */
    static public Set<String> discoverNamespaces() {
        
        List<AggregateResult> results = [
            SELECT NamespacePrefix
            FROM ApexClass
            WHERE NamespacePrefix != 'abstract'
            GROUP BY NamespacePrefix
            HAVING COUNT(Id) < 1000
        ];
        
        Set<String> namespaces = new Set<String>();
        for (AggregateResult result : results)
        namespaces.add((String)result.get('NamespacePrefix'));
        
        return namespaces;
    }
    
}