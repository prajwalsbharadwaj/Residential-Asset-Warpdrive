/**
 * Handles the Mark as Final Resale Quote approval flow.
 * Called from the resaleMarkFinalQuoteAction LWC on the Res Quote page.
 */
public with sharing class ResaleQuoteApprovalController {

    public class ApprovalException extends Exception {}

    @AuraEnabled
    public static String submitForApproval(Id quoteId, String remarks) {
        try {
            Quote q = [
                SELECT Id, Name, Primary__c, Final_Quote__c, Simulation_Status__c,
                    OwnerId, Owner.Name, Owner.Email,
                    AccountId, Account.Name, Account.OwnerId, Account.Owner.Email,
                    OpportunityId, Opportunity.Name,
                    Opportunity.Buyer_Name__c, Opportunity.Buyer_Phone__c,
                    Opportunity.Interested_Unit__r.Name,
                    Opportunity.Interested_Unit__r.Property__r.Name,
                    Opportunity.Expected_Resale_Price__c,
                    Proposed_Resale_Value__c, Resale_Charges__c,
                    Resale_Brokerage_Fee__c, Resale_Discount__c,
                    Final_Resale_Value__c, Simulation_Remarks__c,
                    Original_Booking_Value__c, GrandTotal
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];
            if (String.isNotBlank(remarks)) {
                q.Simulation_Remarks__c = remarks;
            }

            if (q == null) throw new ApprovalException('Quote not found.');

            if (q.Simulation_Status__c == 'Submitted' || q.Simulation_Status__c == 'Approved') {
                throw new ApprovalException(
                    'This Quote has already been ' + q.Simulation_Status__c.toLowerCase() + '.');
            }

            // Clear Final_Quote__c on all other quotes for this opportunity
            if (q.OpportunityId != null) {
                List<Quote> others = [
                    SELECT Id FROM Quote
                    WHERE OpportunityId = :q.OpportunityId
                    AND Id != :quoteId
                    AND Final_Quote__c = true
                ];
                if (!others.isEmpty()) {
                    for (Quote other : others) { other.Final_Quote__c = false; }
                    update others;
                }
            }

            // Mark as Primary, Final, and set status to Submitted
            q.Primary__c = true;
            q.Final_Quote__c = true;
            q.Simulation_Status__c = 'Submitted';
            update q;

            // Submit to approval process (this sends the system approval notification email)
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(quoteId);
            req.setSubmitterId(UserInfo.getUserId());
            req.setComments('Final Resale Quote submitted for approval by ' + UserInfo.getName() + '.');

            try {
                Approval.ProcessResult result = Approval.process(req);
                if (result.isSuccess()) {
                    return 'submitted';
                }
            } catch (Exception apEx) {
                // No approval process configured — fall back to email notification
            }

            // Fallback: try to send email (non-blocking if email fails)
            sendApprovalEmail(q);
            return 'submitted_email_only';

        } catch (ApprovalException ae) {
            throw new AuraHandledException(ae.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Could not submit for approval: ' + e.getMessage());
        }
    }

    private static void sendApprovalEmail(Quote q) {
        String recipientEmail = String.isNotBlank(q.Account?.Owner?.Email)
            ? q.Account.Owner.Email
            : q.Owner?.Email;
        if (String.isBlank(recipientEmail)) return;

        String body = buildApprovalEmailBody(q);

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipientEmail });
        email.setSubject('Approval Required: Final Resale Quote – ' + q.Name
            + ' | ' + q.Opportunity?.Name);
        email.setHtmlBody(body);
        email.setSaveAsActivity(false);
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception e) {
            // Email deliverability restriction — log but do not block submission
            System.debug(LoggingLevel.WARN, 'Approval email not sent: ' + e.getMessage());
        }
    }

    private static String fmtCurrency(Decimal d) {
        return 'INR ' + (d == null ? '0.00' : d.setScale(2).toPlainString());
    }

    private static String buildApprovalEmailBody(Quote q) {
        Decimal proposed = q.Proposed_Resale_Value__c != null ? q.Proposed_Resale_Value__c : 0;
        Decimal charges  = q.Resale_Charges__c != null ? q.Resale_Charges__c : 0;
        Decimal brokerage = q.Resale_Brokerage_Fee__c != null ? q.Resale_Brokerage_Fee__c : 0;
        Decimal discount = q.Resale_Discount__c != null ? q.Resale_Discount__c : 0;
        Decimal grandTotal = q.Final_Resale_Value__c != null
            ? q.Final_Resale_Value__c
            : (proposed + charges + brokerage - discount);

        return '<html><body style="font-family:sans-serif;color:#222">'
            + '<h2 style="color:#1b4332">Final Resale Quote – Approval Required</h2>'
            + '<p>Please review and approve the following final commercial quote:</p>'
            + '<table style="border-collapse:collapse;min-width:500px">'
            + row('Quote Number', q.Name)
            + row('Opportunity', q.Opportunity?.Name)
            + row('Buyer', q.Opportunity?.Buyer_Name__c)
            + row('Unit', q.Opportunity?.Interested_Unit__r?.Name)
            + row('Project', q.Opportunity?.Interested_Unit__r?.Property__r?.Name)
            + row('Original Booking Value', fmtCurrency(q.Original_Booking_Value__c))
            + row('Proposed Resale Value', fmtCurrency(proposed))
            + row('Applicable Charges', fmtCurrency(charges))
            + row('Brokerage / Service Fee', fmtCurrency(brokerage))
            + row('Discount / Adjustment', fmtCurrency(discount))
            + '<tr style="background:#f0f9f4"><td style="padding:10px 16px;font-weight:700;border:1px solid #c8e6d0">Grand Total</td>'
            + '<td style="padding:10px 16px;font-weight:700;border:1px solid #c8e6d0">' + fmtCurrency(grandTotal) + '</td></tr>'
            + row('Commercial Remarks', q.Simulation_Remarks__c != null ? q.Simulation_Remarks__c : '–')
            + '</table>'
            + '<br><p>To approve or reject this quote, open the Quote record in Salesforce and use the Approval History section.</p>'
            + '<p style="font-size:12px;color:#666">This is an automated notification from Nikoo Homes CRM.</p>'
            + '</body></html>';
    }

    private static String row(String label, String val) {
        return '<tr><td style="padding:8px 16px;border:1px solid #ddd;font-weight:600;background:#f9f9f9">'
            + label + '</td><td style="padding:8px 16px;border:1px solid #ddd">'
            + (String.isBlank(val) ? '–' : val) + '</td></tr>';
    }

    @AuraEnabled
    public static void setApprovalStatus(Id quoteId, String status, String comments) {
        if (status != 'Approved' && status != 'Rejected') {
            throw new AuraHandledException('Invalid status: ' + status);
        }
        Quote q = [SELECT Id, Simulation_Status__c, OpportunityId FROM Quote WHERE Id = :quoteId LIMIT 1];
        q.Simulation_Status__c = status;
        update q;

        if (status == 'Approved' && q.OpportunityId != null) {
            updateOpportunityFromQuote(q.OpportunityId, quoteId);
        }
    }

    public static void updateOpportunityFromQuote(Id oppId, Id quoteId) {
        Quote q = [
            SELECT Id, Proposed_Resale_Value__c, Resale_Charges__c,
                Resale_Brokerage_Fee__c, Simulation_Remarks__c,
                Final_Resale_Value__c, GrandTotal
            FROM Quote WHERE Id = :quoteId LIMIT 1
        ];

        Opportunity opp = new Opportunity(Id = oppId);
        opp.Proposed_Resale_Value__c     = q.Proposed_Resale_Value__c;
        opp.Resale_Applicable_Charges__c = q.Resale_Charges__c;
        opp.Resale_Brokerage_Fee__c      = q.Resale_Brokerage_Fee__c;
        opp.Commercial_Remarks__c        = q.Simulation_Remarks__c;
        opp.StageName                    = 'Buyer KYC & Booking Form';
        update opp;
    }
}