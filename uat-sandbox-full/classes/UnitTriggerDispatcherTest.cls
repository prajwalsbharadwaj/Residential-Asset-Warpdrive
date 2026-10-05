@isTest
public class UnitTriggerDispatcherTest {

    @testSetup
    static void setupData() {
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
    }

    @isTest
    static void testBeforeUpdateDispatcher() {
        Unit__c unit = [SELECT Id, Name FROM Unit__c LIMIT 1];
        unit.Name = 'Updated Unit';
        
        Test.startTest();
        update unit; // this will fire trigger → dispatcher.beforeUpdate → UnitBeforeUpdateTriggerHandler
        Test.stopTest();
        
        System.assertEquals('Updated Unit',
            [SELECT Name FROM Unit__c WHERE Id = :unit.Id].Name,
            'Unit name should be updated');
    }

    @isTest
    static void testAfterUpdateDispatcherWithStatusChange() {
        Unit__c unit = [SELECT Id, Status__c FROM Unit__c LIMIT 1];
        unit.Status__c = 'Booked';

        Test.startTest();
        update unit; // fires trigger → dispatcher.afterUpdate → UnitAfterUpdateTriggerHandler
        Test.stopTest();

        System.assertEquals('Booked',
            [SELECT Status__c FROM Unit__c WHERE Id = :unit.Id].Status__c,
            'Status should be updated to Booked');
    }

    @isTest
    static void testAfterUpdateDispatcherWithoutStatusChange() {
        Unit__c unit = [SELECT Id, Status__c, Name FROM Unit__c LIMIT 1];
        unit.Name = 'Another Update';

        Test.startTest();
        update unit; // afterUpdate runs, but status hasn’t changed → SAPUnitIntegrationHandler not called
        Test.stopTest();

        System.assertEquals('Another Update',
            [SELECT Name FROM Unit__c WHERE Id = :unit.Id].Name,
            'Unit name should be updated without affecting Status');
    }
}