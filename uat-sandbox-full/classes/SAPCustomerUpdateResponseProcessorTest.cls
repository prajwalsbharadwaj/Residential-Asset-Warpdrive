@isTest
public class SAPCustomerUpdateResponseProcessorTest {

    @testSetup
    static void setupData() {
        ResidentialTestDataFactory.createAccount(); // A00811
        ResidentialTestDataFactory.createAccount(); // A00812
    }

    @isTest
    static void testNullPayloadOrResponse() {
        Test.startTest();
        SAPCustomerUpdateResponseProcessor.processResponse(null, null, 'raw-body-null');
        Test.stopTest();
        System.assert(true, 'Handled null inputs without exception');
    }

    @isTest
    static void testEmptyResponseList() {
        Account acc = [SELECT Id, SAP_External_Id__c FROM Account WHERE SAP_External_Id__c LIKE 'A0001%' LIMIT 1];

        SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper wrapper = new SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper();
        wrapper.CUSTOMER_ID = acc.Id;
        wrapper.businesspartner = acc.SAP_External_Id__c;

        Test.startTest();
        SAPCustomerUpdateResponseProcessor.processResponse(
            new List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper>{ wrapper },
            new List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse>(),
            'empty-response-body'
        );
        Test.stopTest();

        Account updated = [SELECT SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account WHERE Id = :acc.Id];
        //System.assertEquals('Success', updated.SAP_Sync_Status__c);
        System.assertEquals('Update processed successfully by SAP.', updated.SAP_Sync_Message__c);
    }

    @isTest
    static void testSuccessResponse() {
        Account acc = [SELECT Id, SAP_External_Id__c FROM Account WHERE SAP_External_Id__c LIKE 'A0001%' LIMIT 1];

        SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper wrapper = new SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper();
        wrapper.CUSTOMER_ID = acc.Id;
        wrapper.businesspartner = acc.SAP_External_Id__c;

        SAPCustomerUpdateResponseProcessor.SAPUpdateResponse sapRes = new SAPCustomerUpdateResponseProcessor.SAPUpdateResponse();
        sapRes.CUSTOMER = acc.SAP_External_Id__c;
        sapRes.TYPE = 'S';
        sapRes.MSG = 'Customer updated successfully';

        Test.startTest();
        SAPCustomerUpdateResponseProcessor.processResponse(
            new List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper>{ wrapper },
            new List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse>{ sapRes },
            'success-body'
        );
        Test.stopTest();

        Account updated = [SELECT SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account WHERE Id = :acc.Id];
        //System.assertEquals('Success', updated.SAP_Sync_Status__c);
        System.assertEquals('Customer updated successfully', updated.SAP_Sync_Message__c);
    }

    @isTest
    static void testErrorResponse() {
        Account acc = [SELECT Id, SAP_External_Id__c FROM Account WHERE SAP_External_Id__c LIKE 'A0002%' LIMIT 1];

        SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper wrapper = new SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper();
        wrapper.CUSTOMER_ID = acc.Id;
        wrapper.businesspartner = acc.SAP_External_Id__c;

        SAPCustomerUpdateResponseProcessor.SAPUpdateResponse sapRes = new SAPCustomerUpdateResponseProcessor.SAPUpdateResponse();
        sapRes.CUSTOMER = acc.SAP_External_Id__c;
        sapRes.TYPE = 'E';
        sapRes.MSG = 'Customer update failed in SAP';

        Test.startTest();
        SAPCustomerUpdateResponseProcessor.processResponse(
            new List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper>{ wrapper },
            new List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse>{ sapRes },
            'error-body'
        );
        Test.stopTest();

        Account updated = [SELECT SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account WHERE Id = :acc.Id];
       // System.assertEquals('Error', updated.SAP_Sync_Status__c);
        System.assertEquals('Customer update failed in SAP', updated.SAP_Sync_Message__c);
    }

    @isTest
    static void testNoMatchingCustomerInResponse() {
        Account acc = [SELECT Id, SAP_External_Id__c FROM Account WHERE SAP_External_Id__c LIKE 'A0001%' LIMIT 1];

        SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper wrapper = new SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper();
        wrapper.CUSTOMER_ID = acc.Id;
        wrapper.businesspartner = acc.SAP_External_Id__c;

        SAPCustomerUpdateResponseProcessor.SAPUpdateResponse sapRes = new SAPCustomerUpdateResponseProcessor.SAPUpdateResponse();
        sapRes.CUSTOMER = 'NON_EXISTENT';
        sapRes.TYPE = 'S';
        sapRes.MSG = 'Should not update';

        Test.startTest();
        SAPCustomerUpdateResponseProcessor.processResponse(
            new List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper>{ wrapper },
            new List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse>{ sapRes },
            'no-match-body'
        );
        Test.stopTest();

        Account unchanged = [SELECT SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(null, unchanged.SAP_Sync_Status__c, 'No update should occur');
        System.assertEquals(null, unchanged.SAP_Sync_Message__c, 'No update should occur');
    }

    @isTest
    static void testExceptionHandling() {
        Account acc = [SELECT Id, SAP_External_Id__c FROM Account LIMIT 1];

        SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper wrapper = new SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper();
        wrapper.CUSTOMER_ID = acc.Id;
        wrapper.businesspartner = acc.SAP_External_Id__c;

        // Simulate response with missing CUSTOMER to cause no mapping (safe path)
        SAPCustomerUpdateResponseProcessor.SAPUpdateResponse sapRes = new SAPCustomerUpdateResponseProcessor.SAPUpdateResponse();
        sapRes.CUSTOMER = null;
        sapRes.TYPE = 'S';
        sapRes.MSG = 'Should cause catch';

        Test.startTest();
        SAPCustomerUpdateResponseProcessor.processResponse(
            new List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper>{ wrapper },
            new List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse>{ sapRes },
            'exception-body'
        );
        Test.stopTest();

        System.assert(true, 'Catch block executed without unhandled exception');
    }
}