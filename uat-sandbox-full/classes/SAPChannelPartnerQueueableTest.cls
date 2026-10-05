@isTest
public class SAPChannelPartnerQueueableTest {

    // -----------------------
    // MOCK FOR SAP CALLOUT
    // -----------------------
    private class SAPSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // IMPORTANT: lowercase JSON keys as per updated processor
            String body = '[{"type":"S","srno":"001","vendor":"00001234","msg":"Created"}]';
            res.setBody(body);
            return res;
        }
    }

    private class SAPErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error": "Internal Server Error"}');
            return res;
        }
    }

    // -----------------------
    // TEST SUCCESS SCENARIO
    // -----------------------
    @isTest
    static void testQueueableSuccessFlow() {
        ResidentialTestDataFactory.accountCounter++;
		Account acc = ResidentialTestDataFactory.prepareCPAccount();
        acc.Account_Group__c = 'Residential Sales';
        /* Create Account
        Account acc = new Account(
            Name = 'Test Partner',
            BillingStreet = 'Line1, Line2',
            BillingCity = 'Mumbai',
            BillingPostalCode = '400001',
            BillingState = 'Maharashtra',
            Account_Group__c = 'Residential Sales'
        );
*/
        insert acc;

        // Set mock success response
        Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

        Test.startTest();
        System.enqueueJob(new SAPChannelPartnerQueueable(new List<Id>{ acc.Id }));
        Test.stopTest();

        // Validate Account updated by ResponseProcessor
        Account updated = [
            SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c 
            FROM Account WHERE Id = :acc.Id
        ];

        System.assertEquals('00001234', updated.SAP_External_Id__c);
        System.assertEquals('Success', updated.SAP_Sync_Status__c);
        System.assertEquals('Created', updated.SAP_Sync_Message__c);
    }

    
    // -----------------------
    // TEST ERROR SCENARIO
    // -----------------------
    @isTest
    static void testQueueableErrorFlow() {
		
        ResidentialTestDataFactory.accountCounter++;
		Account acc = ResidentialTestDataFactory.prepareCPAccount();
        acc.Account_Group__c = 'Residential Sales';
        acc.SAP_External_Id__c = null;
        /*
        Account acc = new Account(
            Name = 'Error Case Partner',
            BillingStreet = 'Street 1',
            BillingCity = 'Pune',
            Account_Group__c = 'Residential Sales'
        );
*/
        insert acc;

        // Return 500 error
        Test.setMock(HttpCalloutMock.class, new SAPErrorMock());

        Test.startTest();
        System.enqueueJob(new SAPChannelPartnerQueueable(new List<Id>{ acc.Id }));
        Test.stopTest();

        // FAILURE path → No success update → SAP_Sync fields remain null
        Account updated = [
            SELECT SAP_External_Id__c, SAP_Sync_Status__c 
            FROM Account WHERE Id = :acc.Id
        ];

        System.assertEquals(null, updated.SAP_External_Id__c);
        System.assertEquals('Error', updated.SAP_Sync_Status__c);
    }

    
}