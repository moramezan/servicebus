public with sharing class ApexClassDiscoverExtension {
    
    public ApexClassDiscoverExtension(ApexPages.StandardController controller) {
        //
    }
    
    @RemoteAction static public List<ApexClassModel.Summary> DiscoverSummaries(String namespace) {
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
        List<ApexClassModel.Summary> summaries = new List<ApexClassModel.Summary>();
        
        for (Object dto : (List<Object>)Json.deserializeUntyped(data)) try {
            summaries.add((ApexClassModel.Summary)Json.deserialize(Json.serialize(dto), ApexClassModel.Summary.class));
        } catch (JsonException e) {
            //any error just continue to next summary
        }
        
        return ApexClassSetModel.saveCache(summaries);
    }
    
    static public PageReference DiscoverIfNeeded() {
        if (ApexClassSetModel.cacheKey() == ApexClassSetModel.classKey()) {
            //cache is up to date
            return null;
        }
        
        //service discovery required
        PageReference redirect = Page.ApexClassDiscover;
        redirect.getParameters().put('retURL', ApexPages.currentPage().getUrl());
        return redirect;
    }
    
}