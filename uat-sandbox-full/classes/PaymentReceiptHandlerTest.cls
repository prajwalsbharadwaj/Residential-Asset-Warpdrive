@isTest
public class PaymentReceiptHandlerTest {
    
    // Dummy Mock for SAP callout
    private class SAPReceiptMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"SUCCESS"}');
            return res;
        }
    }
    
    @testSetup
    static void setupData() {
        // Base data from factory
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        List<Booking_Payment_Schedule__c> bps = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
        
        Demand__c demand = new Demand__c(
            SAP_External_Id__c = 'D001',
            Invoice_Value__c = 1000000,
            Booking_Payment_Schedule_Id__c = bps[0].Id,
            Booking_Id__c = booking.Id,
            Account__c = acc.Id,
            Unit__c = unit.Id
        );
        insert demand;
        
        Company_Bank_Account__c ac = new Company_Bank_Account__c();
        ac.Bank_Name__c = 'Standard Chartered Bank';
        ac.Company_Name__c = '2050';
        ac.House_Bank_Id__c = 'STF08';
        ac.IFSC_Code__c = 'HDFC00073';
        ac.Name = '12435686723';
        insert ac;
        
    }
    
    @isTest
    static void testBatchExecutionFromTrigger() {
        // Mock callout
        Test.setMock(HttpCalloutMock.class, new SAPReceiptMock());
        
        // Get IDs
        Set<Id> receiptIds = new Map<Id, Payment_Receipt__c>(
            [SELECT Id FROM Payment_Receipt__c]
        ).keySet();
        booking_payment_schedule__c bps = [SELECT Id FROM booking_payment_schedule__c LIMIT 1];
        Company_Bank_Account__c ac = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];
        demand__c demand = [SELECT Id FROM demand__c LIMIT 1];
        Test.startTest();
        // Database.executeBatch(new PaymentReceiptBatch(receiptIds), 1);
        // Payment Receipt (SAP Sync Pending)
        Payment_Receipt__c receipt = new Payment_Receipt__c(
            ChequeNumber__c = '12345',
            Customer_Bank_Name__c = 'Standard Chartered Bank',
            Amount_Paid__c = 1000000,
            Date_Of_Payment__c = Date.today(),
            Booking_Payment_Schedule__c = bps.Id,
            Demand__c = demand.Id,
            Mode_Of_Payment__c = 'Cheque',
            Company_Bank_Account__c = ac.Id,
            Principal_Applied__c = 500000
        );
        insert receipt;
        Test.stopTest();
    }
}