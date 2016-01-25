public with sharing class ApexClassDiscoverExtension {
    
    public ApexClassDiscoverExtension(ApexPages.StandardController controller) {
        //
    }
    
    @RemoteAction static public Map<String,ApexClassModel.Definition> DiscoverDefinitions(String namespace) {
        return ApexClassSetModel.fromNamespace(namespace).discoverDefinitions();
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
     * - cant do Map<String,Object> (chokes on non-primitive Object)
     * - cant do ApexClassModel.Definition (chokes on extra properties)
     * - we perform serialization on the client side, then iterate over
     */
    @RemoteAction static public Id SaveCache(String data) {
        Map<String,Object> name2data = (Map<String,Object>)Json.deserializeUntyped(data);
        Map<String,ApexClassModel.Definition> name2definition = new Map<String,ApexClassModel.Definition>();
        
        for (String name : name2data.keySet()) try {
            name2definition.put(name, (ApexClassModel.Definition)Json.deserialize(Json.serialize(name2data.get(name)), ApexClassModel.Definition.class));
        } catch (JsonException e) {
            //any error just continue to next definition
        }
        
        return ApexClassSetModel.saveCache(name2definition);
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