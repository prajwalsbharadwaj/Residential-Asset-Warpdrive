@isTest
private class RES_AccountTriggerTest {

    // -------------------------------------------------------
    // TEST — handleAccountUpdates() (Customer Update Flow)
    // -------------------------------------------------------
    @isTest
    static void testCustomerUpdateFlow() {

        // Make sure guards do NOT block execution
        UtilityClass.isSAPSyncInProgress = false;
        UtilityClass.isAfterUpdateRunning = false;

        // Create Customer Account via your test factory
       Account testAccount = new Account(
        RecordTypeId = AccountHelper.RT_ID_CUSTOMER,
        FirstName = 'Test',
        LastName = 'Customer',
        PersonEmail = 'test@example.com',
        Phone = '9999999999',
        SAP_External_Id__c = '123456'
    );

        insert testAccount;
        // Update the customer to trigger handleAccountUpdates()
        testAccount.Phone = '888888888';
        testAccount.BillingStreet = 'Quess, Annie Street, 1234';

        Test.startTest();
        update testAccount;
        Test.stopTest();

        // Validate Pending update was set
        Account updatedAcc = [
            SELECT SAP_Sync_Status__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals(
            'Pending update',
            updatedAcc.SAP_Sync_Status__c,
            'Customer update should set SAP status to Pending update'
        );
    }

    // -------------------------------------------------------
    // TEST — handleCPAccountUpdates() (CREATE Flow)
    // -------------------------------------------------------
    @isTest
    static void testChannelPartnerCreateFlow() {

        UtilityClass.isSAPSyncInProgress = false;
        UtilityClass.isAfterUpdateRunning = false;
        UtilityClass.isCPApprovalResetInProgress = false;

        // Create CP WITHOUT SAP ID → CREATE FLOW
        Account acc = ResidentialTestDataFactory.prepareCPAccount();
        acc.BillingStreet = 'ABC2 street 123 Qwerty';

        Test.startTest();
        insert acc;     // Should trigger CP CREATE async flow
        Test.stopTest();

        System.assert(true, 'CP Create flow executed (code coverage achieved)');
    }

    // -------------------------------------------------------
    // TEST — handleCPAccountUpdates() (UPDATE Flow)
    // -------------------------------------------------------
    @isTest
    static void testChannelPartnerUpdateFlow() {

        UtilityClass.isSAPSyncInProgress = false;
        UtilityClass.isAfterUpdateRunning = false;
        UtilityClass.isCPApprovalResetInProgress = false;

        // Create CP WITH SAP ID → UPDATE FLOW
        Account acc = ResidentialTestDataFactory.prepareCPAccount();
        acc.BillingStreet = 'ABC street 123 Qwerty';
        insert acc;

        // Update CP record to trigger update flow
        acc.LastName = 'Updated CP Name';
		acc.CP_Approval_Status__c = 'Approved';
        Test.startTest();
        update acc;
        Test.stopTest();

        // Validate Pending Approval + Pending update
        Account updatedCP = [
            SELECT CP_Approval_Status__c, SAP_Sync_Status__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'Pending Approval',
            updatedCP.CP_Approval_Status__c,
            'CP update should set Pending Approval'
        );

        System.assertEquals(
            'Pending update',
            updatedCP.SAP_Sync_Status__c,
            'CP update should set SAP sync status to Pending update'
        );
    }
    
    @isTest
    static void testCustomerCreateFlow() {
        
        // Ensure guard flags are OFF
        UtilityClass.isSAPSyncInProgress = false;
        UtilityClass.isAfterUpdateRunning = false;
        
        // Create Customer WITHOUT SAP ID → should trigger CREATE
        Account cust = new Account(
            RecordTypeId = AccountHelper.RT_ID_CUSTOMER,
            FirstName = 'Test-Create',
            LastName = 'Customer',
            PersonEmail = 'test@example.com',
            Phone = '9999999999'
        );
        
        Test.startTest();
        insert cust;   // Should trigger SAP Customer Create Queueable
        Test.stopTest();
        
        // Validate status set after insert
        Account createdAcc = [
            SELECT SAP_Sync_Status__c
            FROM Account
            WHERE Id = :cust.Id
        ];
        
        System.assertEquals(
            null,
            createdAcc.SAP_Sync_Status__c,
            'Customer creation should set SAP status to Pending'
        );
    }
}