public class AccountHelper {
    
    public static Id RT_ID_CUSTOMER;
    public static Id RT_ID_CHANNEL_PARTNER;
    
    static {
        Map<String,Schema.RecordTypeInfo> recordTypeInfoByDevName = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        RT_ID_CUSTOMER = recordTypeInfoByDevName.get('PersonAccount').getRecordTypeId();
        RT_ID_CHANNEL_PARTNER = recordTypeInfoByDevName.get('Channel_Partner_Residential').getRecordTypeId();
    }
    
    // These static maps and methods are utility lookups and can remain here
    public static Map<String, String> stateToRegionCodeMap = new Map<String, String>{
        'Jammu & Kashmir'      => '01',
            'Himachal Pradesh'     => '02',
            'Punjab'               => '03',
            'Chandigarh'           => '04',
            'Uttarakhand'          => '05',
            'Haryana'              => '06',
            'Delhi'                => '07',
            'Rajasthan'            => '08',
            'Uttar Pradesh'        => '09',
            'Bihar'                => '10',
            'Sikkim'               => '11',
            'Arunachal Pradesh'    => '12',
            'Nagaland'             => '13',
            'Manipur'              => '14',
            'Mizoram'              => '15',
            'Tripura'              => '16',
            'Meghalaya'            => '17',
            'Assam'                => '18',
            'West Bengal'          => '19',
            'Jharkhand'            => '20',
            'Odisha'               => '21',
            'Chhattisgarh'         => '22',
            'Madhya Pradesh'       => '23',
            'Gujarat'              => '24',
            'Daman and Diu'        => '25',
            'Dadra Nagr daman diu' => '26',
            'Maharashtra'          => '27',
            'Karnataka'            => '29',
            'Goa'                  => '30',
            'Lakshadweep'          => '31',
            'Kerala'               => '32',
            'Tamil Nadu'           => '33',
            'Puducherry'           => '34',
            'Andaman & Nico.Is.'   => '35',
            'Telangana'            => '36',
            'Andhra Pradesh'       => '37',
            'Ladakh (UT)'          => '38'
            };
                
                public static String getRegionCode(String stateName) {
                    if (String.isNotBlank(stateName) && stateToRegionCodeMap.containsKey(stateName)) {
                        return stateToRegionCodeMap.get(stateName);
                    }
                    return '';
                }
    
    public static String getTitleCode(String salutation) {
        if (String.isBlank(salutation)) {
            return '0002'; // Default to 'Mr.' if nothing provided
        }
        
        Map<String, String> titleCodeMap = new Map<String, String>{'Ms.' => '0001','Mr.'=> '0002','Company'=> '0003'};
            
            return titleCodeMap.containsKey(salutation) ? titleCodeMap.get(salutation) : '0002'; // fallback to '0002'
    }
    
    // Creation
    public void sendAccountsToSAP(List<Account> accountList) {
        System.debug('RT ' + RT_ID_CUSTOMER);
        
        List<Id> custAccountIdsToSend = new List<Id>();
        //List<Id> CP_AccountIdsToSend = new List<Id>();
        System.debug('Acc List ' + accountList);
        for (Account acc : accountList) {
            System.debug('Acc.RT ' + acc.RecordTypeId);
            // Keep the initial filter based on LastName from the trigger context
            if (String.isNotBlank(acc.LastName) && acc.RecordTypeId == AccountHelper.RT_ID_CUSTOMER) {
                //System.debug('To check if this entered the criteria');
                custAccountIdsToSend.add(acc.Id);
            }
        }
        System.debug('accountIdsToSend ' + custAccountIdsToSend);
        System.debug('Account IDs identified for SAP sync: ' + custAccountIdsToSend.size());
        
        if (!custAccountIdsToSend.isEmpty()) {
            // Pass only the list of IDs to the future method
            SAPCustomerIntegrationHandler.sendCustomerDataAsync(custAccountIdsToSend);
        } else {
            System.debug('No eligible customers to send to SAP from the current transaction.');
        }
        /*
        if(!CP_AccountIdsToSend.isEmpty()){
            SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataAsync(CP_AccountIdsToSend);
        } else{
            System.debug('No eligible channel partner to send to SAP from the current transaction.');
        }
*/
    }
    
    public void handleAccountUpdates(List<Account> newAccounts) {        
        
        // Guard 2: Stops queueing a new async job if one is already running.
        if (UtilityClass.isSAPSyncInProgress) {
            System.debug('SAP sync is already in progress. A new update job will not be queued.');
            return;
        }
        Set<Id> customerIdsToUpdateInSAP = new Map<Id, Account>(newAccounts).keySet();
        //List<Id> CP_AccountIdsToSend = new List<Id>();
        
        if (!customerIdsToUpdateInSAP.isEmpty()) { //
            
            List<Account> accountsToSetPending = new List<Account>();
            for (Id accId : customerIdsToUpdateInSAP) {
                accountsToSetPending.add(new Account(
                    Id = accId,
                    SAP_Sync_Status__c = 'Pending update'
                ));
            }
            
            try {
                // Activate synchronous guard BEFORE the DML operation
                UtilityClass.isAfterUpdateRunning = true;
                //UtilityClass.isCPApprovalResetInProgress = true;
                // Perform DML to provide immediate user feedback
                update accountsToSetPending;
                
                // If the update succeeds, queue the asynchronous job for SAP
                SAPCustomerUpdateHandler.sendCustomerUpdateAsync(customerIdsToUpdateInSAP);
                
            } catch (Exception e) {
                // Log any error that occurs during the 'Pending' status update
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('AccountTriggerHelper').withDescription('Failed to set Account status to Pending before SAP update sync.').withClassName('AccountHelper').withMethodName('handleAccountUpdates').withException(e);
                ExceptionLogger.logException(payload);
                
            } finally {
                // CRITICAL: Always reset the synchronous guard to allow for subsequent DML
                UtilityClass.isAfterUpdateRunning = false;
            }
        }
        
    }
    
    public void handleCPAccountUpdates(List<Account> accountsCP) {
        
        // Stop if a sync is already in progress
        if (UtilityClass.isSAPSyncInProgress) {
            System.debug('SAP sync is already in progress. A new update job will not be queued.');
            return;
        }
        
        Set<Id> cpToCreate = new Set<Id>();
        Set<Id> cpToUpdate = new Set<Id>();
        
        for (Account acc : accountsCP) {
            if (String.isBlank(acc.SAP_External_Id__c)) {
                cpToCreate.add(acc.Id);  
            } else {
                cpToUpdate.add(acc.Id);
            }
        }
        // ---------------------------------------------
        //  CREATE FLOW
        // ---------------------------------------------
        if (!cpToCreate.isEmpty()) {
            System.debug('CP Create IDs = ' + cpToCreate);
            SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataAsync(new List<Id>(cpToCreate));
        }
        // ---------------------------------------------
        // Update flow
        // ---------------------------------------------
        if (!cpToUpdate.isEmpty()) {
            // Recursion protection
            if (UtilityClass.isCPApprovalResetInProgress) {
                System.debug('Skipping CP update recursion.');
                return;
            }
            UtilityClass.isCPApprovalResetInProgress = true;
            List<Account> accountsToSetPending = new List<Account>();
            for (Id accId : cpToUpdate) {
                accountsToSetPending.add(new Account(
                    Id = accId,
                    CP_Approval_Status__c = 'Pending Approval',
                    SAP_Sync_Status__c = 'Pending update'
                ));
            }
            
            try {
                UtilityClass.isAfterUpdateRunning = true;
                
                update accountsToSetPending;
                
                SAPChannelPartnerIntegrationHandler.sendChannelPartnerUpdateAsync(
                    new List<Id>(cpToUpdate)
                );
                
            } catch (Exception e) {
                
                ExceptionLogger.ExceptionLogPayload payload =
                    new ExceptionLogger.ExceptionLogPayload().withComponentName('AccountTriggerHelper').withDescription('Failed to set CP status to Pending before SAP update sync.').withClassName('AccountHelper').withMethodName('handleCPAccountUpdates').withException(e);
                ExceptionLogger.logException(payload);
                
            } finally {
                UtilityClass.isAfterUpdateRunning = false;
            }
        }
    }
    
    
}