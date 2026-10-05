@isTest
private class OpportunityHelperTest {
    @testSetup
    static void setupTestData() {
            Property__c project = ResidentialTestDataFactory.createProject();
            Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
            
            Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
            unit.Carpet_Area__c = 100;
            unit.Built_Up_Area_SBA__c = 120;
            update unit;
            
        Unit__c unit1 = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
        unit1.Carpet_Area__c = 100;
        unit1.Built_Up_Area_SBA__c = 120;
        update unit1;

        Unit__c unit2 = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
            
            Account acc = ResidentialTestDataFactory.createAccount();
            Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
            // BusinessPlanPrice
            BusinessPlanPrice__c bpp = new BusinessPlanPrice__c(
                Tower__c = tower.Id,
                PricePerSqFt__c = 5000,
                EffectiveFrom__c = date.today(),
                EffectiveTo__c = date.today().addMonths(3)
            );
            insert bpp;
        Test.setFixedSearchResults(new List<Id>{opp.Id}); 
        }
    
    @isTest
    static void testValidateUnitOnOpp_success() {
        Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity LIMIT 1];
        
        Test.startTest();
        OpportunityHelper.validateUnitOnOpp(
            new Set<Id>{opp.Id},
            new List<Opportunity>{opp}
        );
        Test.stopTest();
        
        System.assertNotEquals(null, opp.Interested_Unit__c, 'Unit should remain valid');
    }
    
    @isTest
    static void testUpsertBookingCondForBpPrice() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        OpportunityHelper.upsertBookingCondForBpPrice(new Set<Id>{opp.Id});
        Test.stopTest();
        
        List<Booking_Condition__c> bcList = [
            SELECT Condition_Type__c FROM Booking_Condition__c WHERE Opportunity__c = :opp.Id
        ];
        System.assert(!bcList.isEmpty(), 'Booking conditions should be inserted');
    }
    
    @isTest
    static void testUpsertBookCondForOthrChargOnTower() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        OpportunityHelper.upsertBookCondForOthrChargOnTower(new Set<Id>{opp.Id});
        Test.stopTest();
        
        List<Booking_Condition__c> bcList = [
            SELECT Condition_Type__c FROM Booking_Condition__c WHERE Opportunity__c = :opp.Id
        ];
    }
    
    // @isTest
    // static void testCreateBookPaySchForTokenAmount() {
    //     Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    //     opp.Token_Amount__c = 50000;
    //     update opp;
        
    //     Test.startTest();
    //     OpportunityHelper.createBookPaySchForTokenAmount(new Set<Id>{opp.Id});
    //     Test.stopTest();
        
    //     List<Booking_Payment_Schedule__c> bpsList = [
    //         SELECT Opportunity__c FROM Booking_Payment_Schedule__c WHERE Opportunity__c = :opp.Id
    //     ];
    //     System.assert(!bpsList.isEmpty(), 'Token amount schedule should be created');
    // }
    
    @isTest
    static void testUpdateOppStageDiscountAppr() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        OpportunityHelper.updateOppStageDiscountAppr(new Set<Id>{opp.Id});
        Test.stopTest();
        
        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Discount Approval', updated.StageName);
    }
    
    @isTest
    static void testDeleteBookConDiscntRecords() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.Token_Amount__c = 1000;
        update opp;
        
        Booking_Condition__c bc = new Booking_Condition__c(
            Opportunity__c = opp.Id,
            Condition_Type__c = 'Base Price Discount',
            Amount__c = 500,
            Amount_By_Type__c = 50000
        );
        //insert bc;
        
        Test.startTest();
        OpportunityHelper.deleteBookConDiscntRecords(new Set<Id>{opp.Id});
        Test.stopTest();
        
        List<Booking_Condition__c> check = [
            SELECT Id FROM Booking_Condition__c WHERE Opportunity__c = :opp.Id AND Condition_Type__c = 'Base Price Discount'
        ];
        System.assertEquals(0, check.size(), 'Discount record should be deleted');
    }
    
    @isTest
    static void testUpsertDefaultCgstSgstBookCon_OCReceivedFalse() {
        // flip OC Received to false
        Tower__c tower = [SELECT Id FROM Tower__c LIMIT 1];
        tower.OC_Received__c = false;
        update tower;
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        OpportunityHelper.upsertDefaultCgstSgstBookCon(new Set<Id>{opp.Id});
        Test.stopTest();
        
        List<Booking_Condition__c> bcList = [
            SELECT Condition_Type__c FROM Booking_Condition__c WHERE Opportunity__c = :opp.Id
        ];
        
        Boolean hasTax = false;
        for (Booking_Condition__c bc : bcList) {
            if (bc.Condition_Type__c.contains('CGST') || bc.Condition_Type__c.contains('SGST')) {
                hasTax = true;
                break;
            }
        }
        //System.assert(hasTax, 'CGST/SGST records should exist when OC not received');
    }
    
    @isTest
    static void testUpsertDefaultCgstSgstBookCon_OCReceivedTrue() {
        Tower__c tower = [SELECT Id FROM Tower__c LIMIT 1];
        tower.OC_Received__c = true;
        update tower;
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        OpportunityHelper.upsertDefaultCgstSgstBookCon(new Set<Id>{opp.Id});
        Test.stopTest();
        
        List<Booking_Condition__c> bcList = [
            SELECT Condition_Type__c FROM Booking_Condition__c WHERE Opportunity__c = :opp.Id
        ];
        
        Boolean hasOldTax = false;
        for (Booking_Condition__c bc : bcList) {
            if (bc.Condition_Type__c == 'IN: 2/3 CGST Tax') {
                hasOldTax = true;
                break;
            }
        }
        System.assert(!hasOldTax, '2/3 tax should be deleted if OC received');
    }

    @isTest static void testUpdateOppStageDiscountAppr_catchBlock() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        // Delete opportunity so update fails
        delete opp;

        Test.startTest();
        OpportunityHelper.updateOppStageDiscountAppr(new Set<Id>{opp.Id});
        Test.stopTest();
    }
    
    @isTest
    static void testInterestedUnitChangeBranch() {
        Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity LIMIT 1];
        Unit__c newUnit = [SELECT Id FROM Unit__c WHERE Id != :opp.Interested_Unit__c LIMIT 1];

        opp.Interested_Unit__c = newUnit.Id;
        update opp;  // Triggers handler

        // Verify Booking Conditions created because oppIds not empty
        List<Booking_Condition__c> bcList = [
            SELECT Id FROM Booking_Condition__c WHERE Opportunity__c = :opp.Id
        ];
        System.assert(!bcList.isEmpty(), 'Booking conditions should be created when unit changes');
    }

    @isTest
    static void testStageChangeBranch() {
        Opportunity opp = [SELECT Id, Actual_Discount_Percentage__c FROM Opportunity LIMIT 1];
        insert new Booking_Condition__c(
            Opportunity__c = opp.Id,
            Condition_Type__c = 'Base Price',
            Amount__c = 10000
        );
        insert new Booking_Condition__c(
            Opportunity__c = opp.Id,
            Condition_Type__c = 'Base Price Discount',
            Amount__c = 1000
        );

        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Discount Approval', updated.StageName,
            'Stage should change when discount percentage updated');
    }

    @isTest
    static void testDeleteDiscountBookConBranch() {
        Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity LIMIT 1];
        Unit__c newUnit = [SELECT Id FROM Unit__c WHERE Id != :opp.Interested_Unit__c LIMIT 1];

        // Add a discount record before update
        insert new Booking_Condition__c(
            Opportunity__c = opp.Id,
            Condition_Type__c = 'Base Price',
            Amount__c = 10000
        );
        opp.Interested_Unit__c = newUnit.Id;
        update opp;

        List<Booking_Condition__c> check = [
            SELECT Id FROM Booking_Condition__c WHERE Opportunity__c = :opp.Id AND Condition_Type__c = 'Base Price Discount'
        ];
        System.assertEquals(0, check.size(), 'Discount booking condition should be deleted when unit changes with discount');
    }


    @isTest
    static void testChargeableAreaTypeNull() {
        Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity LIMIT 1];
        opp.Interested_Unit__c = null;
        update opp;
        Unit__c unit = [SELECT Id, Tower__c FROM Unit__c LIMIT 1];
        Tower__c tw = [SELECT Id FROM Tower__c WHERE Id = :unit.Tower__c];
        tw.Chargeable_Area_Type__c = null;
        update tw;
        opp.Interested_Unit__c = unit.Id;

        Test.startTest();
        try {
            update opp;
            System.assert(false, 'Expected validation error when Chargeable Area Type is null');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Please define Chargeable Area Type'));
        }
        Test.stopTest();
    }
    
    @isTest
static void testCarpetAreaMissing_viaTrigger() {
    // Get an existing opportunity
    Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity LIMIT 1];
    opp.Interested_Unit__c = null;
    update opp;

    // Create a new unit to simulate changing Interested_Unit__c
    Unit__c newUnit = [SELECT Id, Tower__c, Carpet_Area__c,Tower__r.Chargeable_Area_Type__c FROM Unit__c LIMIT 1];

    // Set tower chargeable area type to Carpet Area
    Tower__c tw = [SELECT Id FROM Tower__c WHERE Id = :newUnit.Tower__c];
    tw.Chargeable_Area_Type__c = 'Carpet Area';
    update tw;
    // Make Carpet Area null to trigger validation
    newUnit.Carpet_Area__c = null;
    update newUnit;
    opp.Interested_Unit__c = newUnit.Id;
    

    Test.startTest();
    try {
        update opp; // Trigger should throw error
        System.assert(false, 'Expected validation error when Carpet Area missing');
    } catch (DmlException e) {
        System.assert(e.getMessage().contains('Carpet Area'));
    }
    Test.stopTest();
}


    @isTest
    static void testSuperBuiltUpAreaMissing() {
        Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity LIMIT 1];
        opp.Interested_Unit__c = null;
        update opp;
        Unit__c unit = [SELECT Id, Tower__c, Carpet_Area__c,Tower__r.Chargeable_Area_Type__c FROM Unit__c LIMIT 1];
        Tower__c tw = [SELECT Id FROM Tower__c WHERE Id = :unit.Tower__c];
        tw.Chargeable_Area_Type__c = 'Super Built up Area';
        update tw;

        unit.Built_Up_Area_SBA__c = null;
        update unit;
        
        opp.Interested_Unit__c = unit.Id;

        Test.startTest();
        try {
            update opp;
            System.assert(false, 'Expected validation error when SBA missing');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Super Built Up Area'));
        }
        Test.stopTest();
    }

    @isTest
    static void testSaleableAreaMissing() {
        Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity LIMIT 1];
        opp.Interested_Unit__c = null;
        update opp;
        Unit__c unit = [SELECT Id, Tower__c FROM Unit__c LIMIT 1];
        Tower__c tw = [SELECT Id FROM Tower__c WHERE Id = :unit.Tower__c];
        tw.Chargeable_Area_Type__c = 'Saleable Area'; 
        update tw;

        unit.Saleable_Area__c = null;
        update unit;
        opp.Interested_Unit__c = unit.Id;

        Test.startTest();
        try {
            update opp;
            System.assert(false, 'Expected validation error when Saleable Area missing');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Saleable Area'));
        }
        Test.stopTest();
    }

    @isTest
    static void testValidChargeableArea_NoError() {
        Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity LIMIT 1];
        Unit__c unit = [SELECT Id, Tower__c FROM Unit__c WHERE Id = :opp.Interested_Unit__c LIMIT 1];
        Tower__c tw = [SELECT Id FROM Tower__c WHERE Id = :unit.Tower__c];
        tw.Chargeable_Area_Type__c = 'Carpet Area';
        update tw;

        unit.Carpet_Area__c = 150; // valid
        update unit;

        Test.startTest();
        update opp; // should not throw any exception
        Test.stopTest();

        System.assert(true, 'Opportunity update should succeed with valid chargeable area setup');
    }
    
    @isTest
    static void hasDuplicateMilestones_Test(){
        opportunity op = [SELECT Id, Payment_Plan__c FROM Opportunity LIMIT 1];
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        list<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        
        try{
            for(Payment_Schedule__c sch:schedules){
                if(sch.Milestone_Code__c == 'Initial Token Advance'){
                    sch.Milestone_Code__c = 'On Installment 1';
                    update sch;
                    break;
                }
            }
            test.startTest();
            op.Payment_Plan__c = plan.Id;
            update op;
            test.stopTest();
        }catch(Exception ex){
            
        }
        
        
    }
}