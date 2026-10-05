@isTest
private class UnitTriggerTest {

    private class UnitStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('[]');
            return response;
        }
    }

    @testSetup
    static void setupData() {
        Account account = ResidentialTestDataFactory.createAccount();

        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
    }

    /**
     * @description Ensures unit status change with pending sync triggers the SAP future call.
     * GIVEN: A unit flagged for SAP sync with a pending status update.
     * WHEN: The status value changes via trigger update.
     * THEN: The future handler is invoked and the sync flag is set.
     */
    @isTest
    static void givenPendingSyncWhenStatusChangesThenFutureCallInvoked() {
        UtilityClass.isSAPSyncInProgress = false;
        Unit__c unitRecord = [SELECT Id, Status__c FROM Unit__c LIMIT 1];

        unitRecord.SAP_Sync_Status__c = 'Pending update';
        update unitRecord;

        Unit__c refreshedUnit = [SELECT Id, Status__c, SAP_Sync_Status__c FROM Unit__c WHERE Id = :unitRecord.Id];
        refreshedUnit.Status__c = 'Sold';
        refreshedUnit.SAP_Sync_Status__c = 'Pending update';

        Test.setMock(HttpCalloutMock.class, new UnitStatusMock());
        Test.startTest();
        update refreshedUnit;
        Test.stopTest();

        System.assertEquals(true, UtilityClass.isSAPSyncInProgress, 'Future handler should set the global sync flag when invoked.');
    }

    /**
     * @description Verifies no integration call fires when sync status is not pending.
     * GIVEN: A unit whose status changes but is not marked for SAP sync.
     * WHEN: The trigger processes the update.
     * THEN: No future call occurs and the sync flag remains false.
     */
    @isTest
    static void givenNonPendingSyncWhenStatusChangesThenNoFutureCall() {
        UtilityClass.isSAPSyncInProgress = false;

        
        Unit__c unitRecord = [SELECT Id, Status__c FROM Unit__c LIMIT 1];

        unitRecord.Status__c = 'Sold';
        unitRecord.SAP_Sync_Status__c = 'Success';

        Test.startTest();
        update unitRecord;
        Test.stopTest();

        System.assertEquals(false, UtilityClass.isSAPSyncInProgress, 'Sync flag should remain false when status is not pending.');
    }
}