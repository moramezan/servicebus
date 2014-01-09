public class HealthController
{
    public class Health    {
        public Id ChainId   {get; set;}
        public String ChainName {get; set;} 
        public String Detail {get; set;}
        public String Status {get; set;}        
    }

    public HealthController()
    {
        this.Healths =  new List<Health>();
    }

 
    public List<Health> Healths
    {
        get
        {
            List<Health> healthItems = new List<Health>();
            healthItems.addAll(Sink.getHealth());
            healthItems.addAll(Subscribe.getHealth());
            healthItems.addAll(Publish.getHealth());
            return getSortedHealths(healthItems) ;
        } 
        private set;
    }
    
    @testVisible 
    private List<Health> getSortedHealths(List<Health> unsortedHealths )  {
        List<Health> sortedHealths = new List<Health>();
        
        Map<string, List<Health>> sortkeyToHealths  = new Map<string, List<Health>>  ();
        for (Health  healthItem : unsortedHealths) {
            String sortKey = healthItem.ChainName;
            List<Health> healths = (sortkeyToHealths.get(sortKey) == null) ? new List<Health>() : sortkeyToHealths.get(sortKey);
            healths.add(healthItem);
            sortkeyToHealths.put(sortKey, healths);
        }
        
        List<string>  sortKeys = new List<string>(sortkeyToHealths.keySet());
        sortKeys.sort();
        for (String  sortKey : sortKeys) {
            List<Health>  healths = sortkeyToHealths.get(sortKey);
            sortedHealths.addAll(healths);
        }
          
        return sortedHealths;    
    }

    public Boolean DisplayDetails
    {
        get
        {
            return (this.Healths.size() > 0) ? true : false ;
        }
        private set;
    }

    public static PageReference Refresh()
    {
        return null;
    }
}