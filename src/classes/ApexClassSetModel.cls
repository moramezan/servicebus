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
    static public Id saveCache(Map<String,ApexClassModel.Definition> name2definition) {
        
        Folder folder = [
            SELECT Id
            FROM Folder
            WHERE DeveloperName = 'Services'
        ];
        
        String data = Json.serializePretty(name2definition);
        
        Document document = new Document(
            Name = 'ApexClassCache.bin',
            Description = classKey(),
            FolderId = folder.Id,
            Body = Blob.valueOf(data)
        );
        
        //WTF DeveloperName = 'ApexClassCacheBin',
        //Cannot save cache: Upsert failed. First exception on row 0; first error: DUPLICATE_DEVELOPER_NAME, This Document Unique Name already exists or has been previously used.  Please choose a different name.: [DeveloperName]
        
        upsert document Schema.Document.Name;
        
        return document.Id;
    }
    
    static Map<String,ApexClassModel.Definition> ClassCache;
    
    /**
     * The Sequence Builder and Services Tab
     * rely on reading data from this cache.
     */
    static public Map<String,ApexClassModel.Definition> loadCache() {
        
        if (ClassCache == null) {
            try {
                Document document = [
                    SELECT Body
                    FROM Document
                    WHERE Name = 'ApexClassCache.bin'
                ];
                
                //hydrate cache
                ClassCache = (Map<String,ApexClassModel.Definition>)Json.deserialize(
                    document.Body.toString(),
                    Map<String,ApexClassModel.Definition>.class
                );
                
            } catch (QueryException e) {
                //nothing cached, discovery required!!
                //ClassCache = new Map<String,ApexClassModel.Definition>();
                throw new ModelException('Cache not found, discovery is required.');
            }
        }
        
        //memoize
        return ClassCache;
    }
    
    static public ApexClassSetModel fromNamespace(String namespace) {
        return new ApexClassSetModel([
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE NamespacePrefix = :namespace
            AND Name != 'ApexClassModel'
            AND Name != 'Service'
            ORDER BY Name ASC
        ]);
    }
    
    /**
     * #946 by discovering the namespaces one-by-one with Visualforce Remoting
     * we won't hit the 10 namespace limit, and they run in parallel (fast)
     */
    public Map<String,ApexClassModel.Definition> discoverDefinitions() {
        
        Map<String,ApexClassModel.Definition> name2definition = new Map<String,ApexClassModel.Definition>();
        
        for (ApexClass apexClass : this.ApexClasses) try {
            
            //uses two arguments per #910 to reach out of managed package namespace!
            Type inflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name + '.Definition');
            
            if (inflector == null) {
                //no definition class
                continue;
            }
            
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            ApexClassModel.Definition definition = new ApexClassModel.Definition(reflector);
            definition.Id = apexClass.Id; //gotta provide the id from outside
            name2definition.put(reflector.getName(), definition);
            
        } catch (JsonException e) {
            //fails if compile problem with the class, eg LeadShare when OWD set to public
        }
        
        return name2definition;
        
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