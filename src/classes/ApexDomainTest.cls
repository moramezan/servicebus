@IsTest public class ApexDomainTest {
    
    class UserObject extends ApexDomain.StandardModel {
        public UserObject(User user) {
            super(user);
        }
    }
    
    static testmethod void testDatabaseAccessorRequeriesObject() {
        //arrange
        User user = new User(Id = UserInfo.getUserId());
        UserObject userObject = new UserObject(user);
        
        //act
        SObject sobj = userObject.getRecord();
        String data = Json.serialize(sobj);
        
        //assert
        System.assert(data.contains(UserInfo.getUserName()));
        System.assert(data.contains(UserInfo.getUserEmail()));
        System.assert(data.contains(UserInfo.getFirstName()));
    }
    
    static testmethod void testInMemoryAccessorJustReturnsObject() {
        //arrange
        User user = new User(LastName = 'TestUser');
        UserObject userObject = new UserObject(user);
        
        //act
        SObject sobj = userObject.getRecord();
        
        //assert
        System.assertEquals(user, sobj);
    }
    
    static testmethod void testGetByIdFetchesAllFields() {
        //arrange process
        Process__c process = new Process__c(
            Name = 'foo',
            Setting__c = 'bar',
            FullyQualifiedClassName__c = 'baz'
        );
        insert process;
        
        //act
        SObject sobj = ApexDomain.getById(process.Id);
        String data = Json.serialize(sobj);
        
        //assert
        System.assert(data.contains('foo'));
        System.assert(data.contains('bar'));
        System.assert(data.contains('baz'));
    }
    
    class SequenceSetModel extends ApexDomain.StandardSetModel {
        public SequenceSetModel(List<Sequence__c> sequences) {
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
        List<SObject> sequences = ApexDomain.listAll(Sequence__c.SObjectType);
        Map<Id,SObject> id2sequence = ApexDomain.mapAll(Sequence__c.SObjectType);
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
        SequenceSetModel objs = new SequenceSetModel(new List<Sequence__c>{one, two});
        
        //act
        Set<Id> ids = objs.keySet();
        
        //assert
        Id idOne = one.Id;
        Id idTwo = two.Id;
        System.assert(ids.contains(idOne));
        System.assert(ids.contains(idTwo));
    }
}