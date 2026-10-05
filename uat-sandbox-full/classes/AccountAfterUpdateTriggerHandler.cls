public class AccountAfterUpdateTriggerHandler extends TriggerHandlerBase {
    private AccountHelper helper = new AccountHelper();
    
    public override void mainEntry(TriggerParameters tp) {
        process((List<Account>)tp.newList, (Map<Id,Account>)tp.oldMap);
    }
    
    private void process(List<Account> records,Map<Id,Account> oldMapRecords) {
        list <account> accountsToProcess = new list<Account>();
        list <account> CPaccountsToProcess = new list<Account>();
        //Set<Id> accountIdsToProcess = new Set<Id>();
        //Set<Id> CPaccountIdsToProcess = new Set<Id>();
        for(account ac:records){
            if((ac.RecordTypeId == AccountHelper.RT_ID_CUSTOMER) &&
               ac.SAP_External_Id__c != null && ac.SAP_Sync_Status__c != 'Pending' && isCustomerAccountsFieldUpdatedForSAPSync(ac, oldMapRecords.get(ac.Id))){
                   accountsToProcess.add(ac);
               }
            else if(ac.RecordTypeId == AccountHelper.RT_ID_CHANNEL_PARTNER && oldMapRecords.get(ac.Id).CP_Approval_Status__c != ac.CP_Approval_Status__c && ac.CP_Approval_Status__c == 'Approved' ){
                CPaccountsToProcess.add(ac);
            }
        }
        if(!accountsToProcess.isEmpty()){
            helper.handleAccountUpdates(accountsToProcess);
        }
        if(!CPaccountsToProcess.isEmpty()){
            helper.handleCPAccountUpdates(CPaccountsToProcess);
        }
    }
    
    private Boolean isCustomerAccountsFieldUpdatedForSAPSync(Account acc, Account oldAcc){
        List<String> fields = new List<String>{
                'FirstName',
                'Middle_Name__c',
                'LastName',
                'Search_Term_1__c',
                'BillingStreet',
                'BillingPostalCode',
                'BillingCity',
                'BillingCountryCode',
                'BillingState',
                'Phone',
                'PersonEmail',
                'GST_No__c',
                'PAN_Number__c',
                'Company_Code__c',
                'Reconciliation_Account__c',
                'Sales_Org__c',
                'Distribution_Channel__c',
                'Division__c',
                'Shipping_Condition__c',
                'Tax_Class_CGST__c',
                'Tax_Class_SGST__c',
                'Tax_Class_IGST__c',
                'Tax_Class_UTGST__c',
                'IFSC_Code__c',
                'BANK_ACCOUNT_NO__c',
                'Beneficiary_Name_Account_Holder_Name__c',
                'Sales_Group__c',
                'Aadhar_Number__c'
                };
                    Boolean isFieldsChanged = false;
        for(String field: fields){
            if(acc.get(field) != oldAcc.get(field)){
                isFieldsChanged = true;
                break;
            }
        }
        
        return isFieldsChanged;
        
    }
}