public with sharing class ApexClassDiscoverExtension {
    
    public ApexClassDiscoverExtension(ApexPages.StandardController controller) {
        //
    }
    
    @RemoteAction static public Map<String,ApexClassModel.Summary> DiscoverSummaries(String namespace) {
        return ApexClassSetModel.fromNamespace(namespace).discoverSummaries();
    }
    
    static public String getNamespaces() {
        return Json.serialize(ApexClassSetModel.discoverNamespaces());
    }
    
    /**
     * The explicit JSON serializer in Apex is very good. It ignores
     * extra fields, and leaves any missing fields with null values.
     *
     * But the implicit de/serializer used in JavaScript Remoting runs
     * in strict mode and doesnt support Object/ANY. So we use String:
     *
     * - cant do ApexClass.Summary (chokes on extra properties)
     * - cant do Map<String,Object> (chokes on non-primitive Object)
     * - we perform serialization on the client side, then iterate over
     */
    @RemoteAction static public Id SaveCache(String data) {
        Map<String,Object> name2data = (Map<String,Object>)Json.deserializeUntyped(data);
        Map<String,ApexClassModel.Summary> name2summary = new Map<String,ApexClassModel.Summary>();
        
        for (String name : name2data.keySet()) try {
            name2summary.put(name, (ApexClassModel.Summary)Json.deserialize(Json.serialize(name2data.get(name)), ApexClassModel.Summary.class));
        } catch (JsonException e) {
            //any error just continue to next summary
        }
        
        return ApexClassSetModel.saveCache(name2summary);
    }
    
    /**
     * Determins if service discovery is required.
     * If so, this ApexClassDiscover page is returned.
     */
    static public PageReference DiscoverIfNeeded(PageReference retURL) {
        
        if (ApexClassSetModel.cacheKey() != ApexClassSetModel.classKey()) {
            //cache empty or cache outdated, service discovery required
            PageReference discover = Page.ApexClassDiscover;
            discover.getParameters().put('retURL', retURL.getUrl());
            return discover;
        }
        
        //cache is up to date
        return null;
    }
    
}