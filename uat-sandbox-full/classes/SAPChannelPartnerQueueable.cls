public class SAPChannelPartnerQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> accountIdsToProcess;

    // The constructor accepts the list of IDs to be processed.
    public SAPChannelPartnerQueueable(List<Id> accountIds) {
        this.accountIdsToProcess = accountIds;
    }

    public void execute(QueueableContext context) {
        // If there's nothing left to process, exit. This is our stop condition.
        if (accountIdsToProcess == null || accountIdsToProcess.isEmpty()) {
            return;
        }
        // --- STEP 1: Process the FIRST record in the list ---
        Id accountId = accountIdsToProcess.remove(0); // Take the first ID and remove it from the list
        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ]; 
        if(accounts.isEmpty()){
            // If the account was deleted or merged, chain to the next one.
            if (!accountIdsToProcess.isEmpty()) {System.enqueueJob(new SAPChannelPartnerQueueable(accountIdsToProcess));}return;
        }  
       	SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataSync(accounts.get(0).Id);
        // --- STEP 4: Chain to the next job if there are more records ---
        if (!accountIdsToProcess.isEmpty()) {System.enqueueJob(new SAPChannelPartnerQueueable(accountIdsToProcess));}
    }


}