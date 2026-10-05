public class AccountAfterInsertTriggerHandler extends TriggerHandlerBase {
    
    private AccountHelper helper = new AccountHelper();
    
    public override void mainEntry(TriggerParameters tp) {
        process((List<Account>)tp.newList);
    }
    
    private void process(List<Account> records) {
        list <account> accountsToProcess = new list<Account>();
        for(account ac:records){
            if((ac.RecordTypeId == AccountHelper.RT_ID_CUSTOMER) &&
              ac.SAP_External_Id__c == null){
                accountsToProcess.add(ac);
            }
        }
        if(!accountsToProcess.isEmpty()){
            helper.sendAccountsToSAP(accountsToProcess);
        }
    }
}