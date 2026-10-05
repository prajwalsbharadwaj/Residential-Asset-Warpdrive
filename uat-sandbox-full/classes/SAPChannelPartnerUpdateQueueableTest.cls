@isTest
public class SAPChannelPartnerUpdateQueueableTest {

    // ------------------------------------------------
    // MOCK FOR SUCCESS RESPONSE FROM SAP
    // ------------------------------------------------
    private class SAPSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            // Response uses lowercase JSON as per processor requirement
            String body = '[{"type":"S","srno":"001","vendor":"00001234","msg":"Updated Successfully"}]';
            res.setBody(body);
            return res;
        }
    }

    // ------------------------------------------------
    // MOCK FOR FAILURE RESPONSE FROM SAP
    // ------------------------------------------------
    private class SAPErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error": "Internal Server Error"}');
            return res;
        }
    }


    // ------------------------------------------------
    // TEST SUCCESS SCENARIO
    // ------------------------------------------------
    @isTest
    static void testQueueableSuccessFlow() {

        // Create test account
        ResidentialTestDataFactory.accountCounter++;
		Account acc = ResidentialTestDataFactory.prepareCPAccount();
        acc.Account_Group__c = 'Residential Sales';
        /*
        Account acc = new Account(
            Name = 'Test Partner',
            BillingStreet = 'Line1, Line2',
            BillingCity = 'Mumbai',
            BillingPostalCode = '400001',
            BillingState = 'Maharashtra',
            Account_Group__c = 'Residential Sales',
            SAP_External_Id__c = '00001234'
        );
*/
        insert acc;

        // Mock successful SAP response
        Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

        Test.startTest();
        System.enqueueJob(new SAPChannelPartnerUpdateQueueable(new List<Id>{ acc.Id }));
        Test.stopTest();

        // Validate account updated
        Account updated = [
            SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals('00001234', updated.SAP_External_Id__c);
        System.assertEquals('Success', updated.SAP_Sync_Status__c);
        System.assertEquals('Updated Successfully', updated.SAP_Sync_Message__c);
    }



    // ------------------------------------------------
    // TEST ERROR SCENARIO
    // ------------------------------------------------
    @isTest
    static void testQueueableErrorFlow() {
		
        ResidentialTestDataFactory.accountCounter++;
		Account acc = ResidentialTestDataFactory.prepareCPAccount();
        acc.Account_Group__c = 'Residential Sales';
        acc.SAP_External_Id__c = '123456';
        insert acc;

        // Mock error from SAP
        Test.setMock(HttpCalloutMock.class, new SAPErrorMock());

        Test.startTest();
        System.enqueueJob(new SAPChannelPartnerUpdateQueueable(new List<Id>{ acc.Id }));
        Test.stopTest();

        // FAILURE → Sync fields should remain unchanged
        Account updated = [
            SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals('123456', updated.SAP_External_Id__c); // unchanged
        System.assertEquals('Error', updated.SAP_Sync_Status__c);
        System.assertEquals('{"error": "Internal Server Error"}', updated.SAP_Sync_Message__c);
    }

}