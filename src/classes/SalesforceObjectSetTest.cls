@IsTest public class SalesforceObjectSetTest {
	
    class SequenceObjectSet extends SalesforceObjectSet {
        public SequenceObjectSet(List<Sequence__c> sequences) {
            super(sequences);
        }
    }
    
    static testmethod void testListAllAndMapAllGetsAllObjects() {
        //arrange data
        Database.insert(new List<Sequence__c>{
            new sequence__c(Name = 'TestSequenceOne'),
            new sequence__c(Name = 'TestSequenceTwo'),
            new sequence__c(Name = 'TestSequenceThree')
        });
        
        //act
        List<SObject> sequences = SalesforceObjectSet.listAll(Sequence__c.SObjectType);
        Map<Id,SObject> id2sequence = SalesforceObjectSet.mapAll(Sequence__c.SObjectType);
        Integer expectedSize = 3;
        
        //assert
        Integer actualListSize = sequences.size();
        Integer actualMapSize = id2sequence.size();
        System.assertEquals(expectedSize, actualListSize);
        System.assertEquals(expectedSize, actualMapSize);
    }
    
    static testmethod void testKeySetReturnsIds() {
        //arrange data
        Sequence__c one = new sequence__c(Name = 'SequenceOne');
        Sequence__c two = new sequence__c(Name = 'SequenceTwo');
        insert one;
        insert two;
        
        //arrange salesforce object set
        SequenceObjectSet objs = new SequenceObjectSet(new List<Sequence__c>{one, two});
        
        //act
        Set<Id> ids = objs.keySet();
        
        //assert
        Id idOne = one.Id;
        Id idTwo = two.Id;
        System.assert(ids.contains(idOne));
        System.assert(ids.contains(idTwo));
    }
    
}