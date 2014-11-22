@IsTest public class SalesforceObjectTest {
    
    class UserObject extends SalesforceObject {
        public UserObject(User user) {
            super(user);
        }
    }
    
    static testmethod void testDatabaseAccessorRequeriesObject() {
        //arrange
        User user = new User(Id = UserInfo.getUserId());
        UserObject userObject = new UserObject(user);
        
        //act
        SObject sobj = userObject.getSObject();
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
        SObject sobj = userObject.getSObject();
        
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
        SObject sobj = SalesforceObject.getById(process.Id);
        String data = Json.serialize(sobj);
        
        //assert
        System.assert(data.contains('foo'));
        System.assert(data.contains('bar'));
        System.assert(data.contains('baz'));
    }
    
}