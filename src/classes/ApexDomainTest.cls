@IsTest public class ApexDomainTest {
    
    @TestVisible private class ContactModel extends ApexDomain.StandardModel {
        public ContactModel(Contact contact) {
            super(contact);
        }
    }
    
    @TestVisible private class ContactSetModel extends ApexDomain.StandardSetModel {
        public ContactSetModel(List<Contact> contacts) {
            super(contacts);
        }
    }
    
    static testmethod void testAccessors() {
        //arrange domain layer
        Contact contact = new Contact(Id = '003000000000000AAA');
        ContactModel contactObj = new ContactModel(contact);
        
        //act
        Id contactId = contactObj.getId();
        Id recordId = contactObj.getRecord().Id;
        
        //assert
        Id expectedId = '003000000000000AAA';
        Id actualId = contactId;
        System.assertEquals(expectedId, actualId, 'Wrong Id');

        expectedId = '003000000000000AAA';
        actualId = recordId;
        System.assertEquals(expectedId, actualId, 'Wrong Id');
    }
    
    static testmethod void testSetAccessors() {
        //arrange domain layer
        Contact contact = new Contact(Id = '003000000000000AAA');
        ContactSetModel contactsObj = new ContactSetModel(new List<Contact>{contact});
        
        //act
        Id contactId = contactsObj.getRecords()[0].Id;
        
        //assert
        Id expectedId = '003000000000000AAA';
        Id actualId = contactId;
        System.assertEquals(expectedId, actualId, 'Wrong Id');
    }
    
    static testmethod void testGetByIdFetchesAllFields() {
        //arrange data
        Document document = new Document(
            Name = 'foo',
            FolderId = UserInfo.getUserId(),
            Body = Blob.valueOf('bar')
        );
        insert document;
        
        //act
        SObject sobj = ApexDomain.getById(document.Id);
        String data = Json.serialize(sobj);
        
        //assert
        System.assert(data.contains('foo'));
        System.assert(data.contains(UserInfo.getUserId()));
    }
    
    class SequenceSetModel extends ApexDomain.StandardSetModel {
        public SequenceSetModel(List<Sequence__c> sequences) {
            super(sequences);
        }
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