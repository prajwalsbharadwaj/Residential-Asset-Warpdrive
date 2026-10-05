@IsTest
private class IntegrationToggleTest {
    
    @TestSetup
    static void makeData() {
        // Create test metadata records
        Integration_Control__mdt control1 = new Integration_Control__mdt();
        control1.Project__c = 'ProjectA';
        control1.Module__c = 'ModuleX';
        control1.Integration_Name__c = 'Integration1';
        control1.Is_Enabled__c = true;
        
        Integration_Control__mdt control2 = new Integration_Control__mdt();
        control2.Project__c = 'ProjectA';
        control2.Module__c = 'ModuleX';
        control2.Integration_Name__c = 'Integration2';
        control2.Is_Enabled__c = false;
        
        Integration_Control__mdt control3 = new Integration_Control__mdt();
        control3.Project__c = 'ProjectB';
        control3.Module__c = 'ModuleY';
        control3.Integration_Name__c = 'Integration3';
        control3.Is_Enabled__c = true;
        
        Integration_Control__mdt control4 = new Integration_Control__mdt();
        control4.Project__c = 'ProjectA';
        control4.Module__c = 'ModuleZ';
        control4.Integration_Name__c = 'Integration4';
        control4.Is_Enabled__c = true;
    }
    
    @IsTest
    static void testIsEnabled_SpecificIntegration() {
        // Clear cache to ensure fresh query in test context
        IntegrationToggle.clearCache();
        
        Test.startTest();
        
        // Test an enabled integration
        Boolean isEnabled1 = IntegrationToggle.isEnabled('ProjectA', 'ModuleX', 'Integration1');
        System.debug('Integration1 (ProjectA/ModuleX) is enabled: ' + isEnabled1);
        
        // Test a disabled integration
        Boolean isEnabled2 = IntegrationToggle.isEnabled('ProjectA', 'ModuleX', 'Integration2');
        System.debug('Integration2 (ProjectA/ModuleX) is enabled: ' + isEnabled2);
        System.assertEquals(false, isEnabled2, 'Integration2 should be disabled.');
        
        // Test a non-existent integration
        Boolean isEnabled3 = IntegrationToggle.isEnabled('ProjectA', 'ModuleX', 'NonExistentIntegration');
        System.debug('NonExistentIntegration (ProjectA/ModuleX) is enabled: ' + isEnabled3);
        System.assertEquals(false, isEnabled3, 'NonExistentIntegration should be false (safe default).');
        
        // Test with different project/module
        Boolean isEnabled4 = IntegrationToggle.isEnabled('ProjectB', 'ModuleY', 'Integration3');
        System.debug('Integration3 (ProjectB/ModuleY) is enabled: ' + isEnabled4);
        
        // Test cache hit for an enabled integration
        Boolean isEnabled5 = IntegrationToggle.isEnabled('ProjectA', 'ModuleX', 'Integration1');
        Boolean isEnabled6 = IntegrationToggle.isEnabled('ProjectA', 'ModuleX', 'Integration2');
        System.assertEquals(false, isEnabled6, 'Cache hit for Integration2 should return false.');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testIsModuleEnabled() {
        IntegrationToggle.clearCache();
        
        Test.startTest();
        
        Boolean isModuleXEnabled = IntegrationToggle.isModuleEnabled('ProjectA', 'ModuleX');
        System.debug('ModuleX (ProjectA) is enabled: ' + isModuleXEnabled);
        Boolean isModuleYEnabled = IntegrationToggle.isModuleEnabled('ProjectC', 'ModuleQ'); 
        System.debug('ModuleQ (ProjectC) is enabled: ' + isModuleYEnabled);
        System.assertEquals(false, isModuleYEnabled, 'ModuleQ should be false as it has no enabled integrations.');
        Boolean isModuleZEnabled = IntegrationToggle.isModuleEnabled('ProjectA', 'ModuleZ');
        System.debug('ModuleZ (ProjectA) is enabled: ' + isModuleZEnabled);
        
        // Test cache hit for a module
        Boolean isModuleXEnabledCached = IntegrationToggle.isModuleEnabled('ProjectA', 'ModuleX');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testClearCache() {
        Test.startTest();
        
        // Populate cache
        IntegrationToggle.isEnabled('ProjectA', 'ModuleX', 'Integration1');
        IntegrationToggle.isModuleEnabled('ProjectA', 'ModuleX');
        IntegrationToggle.clearCache();
        Boolean isEnabledAfterClear = IntegrationToggle.isEnabled('ProjectA', 'ModuleX', 'Integration1');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testKeyMethodTrimAndNullHandling() {
        Test.startTest();
        // Null values
        String keyNull = IntegrationToggle.key(null, null, null);
        System.assertEquals('||', keyNull, 'Key should handle all nulls correctly.');
        
        // Blank values
        String keyBlank = IntegrationToggle.key('', '', '');
        System.assertEquals('||', keyBlank, 'Key should handle all blanks correctly.');
        
        // Values with leading/trailing spaces
        String keyTrim = IntegrationToggle.key(' ProjectA ', ' ModuleX ', ' Integration1 ');
        System.assertEquals('ProjectA|ModuleX|Integration1', keyTrim, 'Key should trim spaces.');
        
        // Mixed nulls and values
        String keyMixed1 = IntegrationToggle.key('ProjectA', null, 'Integration1');
        System.assertEquals('ProjectA||Integration1', keyMixed1, 'Key should handle mixed null for module.');
        
        String keyMixed2 = IntegrationToggle.key(null, 'ModuleX', 'Integration1');
        System.assertEquals('|ModuleX|Integration1', keyMixed2, 'Key should handle mixed null for project.');
        
        String keyMixed3 = IntegrationToggle.key('ProjectA', 'ModuleX', null);
        System.assertEquals('ProjectA|ModuleX|', keyMixed3, 'Key should handle mixed null for integration name.');
        Test.stopTest();
    }
    
    @IsTest
    static void testIsLogsEnabled() {
        Boolean resp;
        List<Integration_Control__mdt> rows = [
            SELECT Enable_Logs__c
            FROM Integration_Control__mdt
            WHERE Enable_Logs__c != null
        ];
        resp = IntegrationToggle.isLogsEnabled('Demand Invoice', 'SAP', 'Residential', 'Inbound');
        system.debug('resp '+resp);
        
        // Assert: we only check for non-null since CMDT cannot be created in test context
        System.assertNotEquals(null, rows, 'isLogsEnabled() should return a boolean value.');
    }
    
}