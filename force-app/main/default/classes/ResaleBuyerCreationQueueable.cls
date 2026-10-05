/**
 * Asynchronously creates an Account and Contact for the new buyer on a
 * Resale Assistance Opportunity, then links them back to the Opportunity.
 *
 * Running asynchronously ensures that any failure here does NOT roll back
 * the original Opportunity creation.
 */
public class ResaleBuyerCreationQueueable implements Queueable {

    private List<Id> oppIds;

    public ResaleBuyerCreationQueueable(List<Id> oppIds) {
        this.oppIds = oppIds;
    }

    public void execute(QueueableContext ctx) {
        List<Opportunity> opps = [
            SELECT Id, Buyer_Name__c, Buyer_Phone__c, Buyer_Email__c, AccountId
            FROM Opportunity
            WHERE Id IN :oppIds
              AND AccountId = null
              AND Buyer_Name__c != null
        ];

        if (opps.isEmpty()) return;

        List<Account> accounts = new List<Account>();
        for (Opportunity opp : opps) {
            Account acc = new Account(
                Name = opp.Buyer_Name__c
            );
            if (String.isNotBlank(opp.Buyer_Phone__c)) acc.Phone = opp.Buyer_Phone__c;
            if (String.isNotBlank(opp.Buyer_Email__c))  acc.PersonEmail = opp.Buyer_Email__c;
            accounts.add(acc);
        }

        try {
            insert accounts;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ResaleBuyerCreationQueueable: Account insert failed: ' + e.getMessage());
            return;
        }

        List<Contact> contacts = new List<Contact>();
        List<Opportunity> toUpdate = new List<Opportunity>();

        for (Integer i = 0; i < opps.size(); i++) {
            Opportunity opp = opps[i];
            Account acc = accounts[i];

            String fullName = opp.Buyer_Name__c.trim();
            Integer spaceIdx = fullName.indexOf(' ');
            String firstName = spaceIdx > 0 ? fullName.substring(0, spaceIdx) : '';
            String lastName  = spaceIdx > 0 ? fullName.substring(spaceIdx + 1) : fullName;

            Contact con = new Contact(
                AccountId   = acc.Id,
                FirstName   = firstName,
                LastName    = lastName
            );
            if (String.isNotBlank(opp.Buyer_Phone__c)) con.MobilePhone = opp.Buyer_Phone__c;
            if (String.isNotBlank(opp.Buyer_Email__c))  con.Email       = opp.Buyer_Email__c;
            contacts.add(con);

            toUpdate.add(new Opportunity(
                Id        = opp.Id,
                AccountId = acc.Id,
                Name      = opp.Buyer_Name__c
            ));
        }

        try {
            insert contacts;
            for (Integer i = 0; i < toUpdate.size(); i++) {
                toUpdate[i].Buyer_Contact__c = contacts[i].Id;
            }
            update toUpdate;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ResaleBuyerCreationQueueable: Contact/Opp update failed: ' + e.getMessage());
        }
    }
}