public class SAPChannelPartnerUpdateQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> accountIdsToProcess;

    public SAPChannelPartnerUpdateQueueable(List<Id> accountIds) {
        this.accountIdsToProcess = accountIds;
    }

    public void execute(QueueableContext context) {
        if (accountIdsToProcess == null || accountIdsToProcess.isEmpty()) {
           return;
        }

        Id accountId = accountIdsToProcess.remove(0);

        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if(accounts.isEmpty()){
            if (!accountIdsToProcess.isEmpty()) {System.enqueueJob(new SAPChannelPartnerUpdateQueueable(accountIdsToProcess));}return;
        }

       	SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataSync(accounts.get(0).Id);

        if (!accountIdsToProcess.isEmpty()) {System.enqueueJob(new SAPChannelPartnerUpdateQueueable(accountIdsToProcess));}
    }

}