/**
 * PaymentReceiptValidator
 * ---------------------------------------------------------
 * PURPOSE
 *  BEFORE UPDATE: validate only on status transitions.
 *   A) -> Submitted : light checks (requireds, non-negative, Amount >= P+I+Tax)
 *   B) -> Approved  : full checks (accrual preview, waiver cap, principal & interest caps)
 *
 * NOTES
 *  - No validations while still Draft.
 *  - We do not handle reverse/unapply; only the moment of approval matters.
 */
public class PaymentReceiptValidator {

    public static void validateOnStatusChange(List<Payment_Receipt__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        List<Payment_Receipt__c> forSubmitted = new List<Payment_Receipt__c>();

        for (Payment_Receipt__c r : newList) {
            if (r.Receipt_Status__c != 'Cancelled' && r.Receipt_Status__c != 'Bounced') {
                forSubmitted.add(r);
            }
            //if (newStatus == 'Approved'  && oldStatus != 'Approved')  forApproved.add(r);
        }

        if (!forSubmitted.isEmpty()) validateSubmitted(forSubmitted);
        //if (!forApproved.isEmpty())  validateApproved(forApproved);
    }

    // ---------- A) Submitted ----------
    private static void validateSubmitted(List<Payment_Receipt__c> rows) {
        for (Payment_Receipt__c r : rows) {
            if (r.Demand__c == null)          r.Demand__c.addError('Demand is required.');
            if (r.Date_Of_Payment__c == null) r.Date_Of_Payment__c.addError('Date of Payment is required.');
            if (r.Amount_Paid__c == null)     r.Amount_Paid__c.addError('Amount Paid is required.');

            if (r.Principal_Applied__c == null) r.Principal_Applied__c = 0;
            if (r.Interest_Applied__c  == null) r.Interest_Applied__c  = 0;
            if (r.Tax_on_Interest__c   == null) r.Tax_on_Interest__c   = 0;

            // Non-negative splits
            if (FinancePolicyProvider.nz(r.Principal_Applied__c) < 0) r.Principal_Applied__c.addError('Principal cannot be negative.');
            if (FinancePolicyProvider.nz(r.Interest_Applied__c)  < 0) r.Interest_Applied__c.addError('Interest cannot be negative.');
            if (FinancePolicyProvider.nz(r.Tax_on_Interest__c)   < 0) r.Tax_on_Interest__c.addError('Tax on interest cannot be negative.');

            // Amount must cover split (excess >= 0)
            Decimal split = FinancePolicyProvider.nz(r.Principal_Applied__c) + FinancePolicyProvider.nz(r.Interest_Applied__c) + FinancePolicyProvider.nz(r.Tax_on_Interest__c);
            if (r.Amount_Paid__c != null && FinancePolicyProvider.nz(r.Amount_Paid__c) < split) {
                r.Amount_Paid__c.addError('Amount Paid is less than Principal + Interest + Tax.');
            }
        }
    }

    
}