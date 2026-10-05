import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';
import ACCOUNT_FIELD from '@salesforce/schema/Demand__c.Account__c';
import BOOKINGPAYMENTSCH_FIELD from '@salesforce/schema/Demand__c.Booking_Payment_Schedule_Id__c';
import OUTSTANDING_PRINCIPAL_FIELD from '@salesforce/schema/Booking_Payment_Schedule__c.Outstanding_Principal__c';
import GST_VAT_RATE_ON_INTEREST_FIELD from '@salesforce/schema/Booking_Payment_Schedule__c.GST_VAT_Rate_On_Interest__c';
import { NavigationMixin } from 'lightning/navigation';


export default class PaymentReceiptRecordPage extends NavigationMixin(LightningElement) {
@api recordId; 
accountId;
bookingPaymentScheduleId;
amountPaid = 0;
principalFloat = 0;
interestApplied = 0;
gstVatRateOnInterest = 0;
taxOnInterest = 0;
excessPayment = 0;
loading = false;
disableCustomerBankName = false;
fixedOutstandingPrincipal = 0;
remainingPrincipalValue = 0;
requiredCompanyBankAccount = true;
isSubmitting = false;

formReady = false; // Will become true once data is ready
// Flags for conditional fields
showChequeNumber = false;
showTransactionReference = false;
showCertificateAndChallan = false;


handlePaymentModeChange(event) {
    const selected = event.target.value;

    // Reset all flags
    this.showChequeNumber = false;
    this.showTransactionReference = false;
    this.showCertificateAndChallan = false;

    if (selected === 'Cheque') {
        this.showChequeNumber = true;
        this.disableCustomerBankName = false;
        this.requiredCompanyBankAccount = true;
    } 
    else if (selected === 'TDS') {
        this.showCertificateAndChallan = true;
        this.disableCustomerBankName = true;
        this.requiredCompanyBankAccount = false;
    } 
    else if (
        selected === 'RTGS' || 
        selected === 'Net Banking' || 
        selected === 'Bank Disbursement' ||
        selected === 'Demand Draft'
    ) {
        this.showTransactionReference = true;
        this.disableCustomerBankName = false;
        this.requiredCompanyBankAccount = true;;
    }
}

handleFieldChange(event) {
    const fieldName = event.target.fieldName;
    const value = Number(event.target.value);
    if (isNaN(value)) value = 0;

    // Update local tracked values based on field change
    if (fieldName === 'Amount_Paid__c') {
        this.amountPaid = value;
        this.calculatePrincipalApplied();
        this.calculateRemainingPrincipal();
    } else if (fieldName === 'Principal_Applied__c') {
        this.principalFloat = value;
        this.calculateRemainingPrincipal();
    } else if (fieldName === 'Interest_Applied__c') {
        this.interestApplied = value;

        // Automatically calculate Tax_on_Interest__c when Interest changes
        if (this.gstVatRateOnInterest) {
            this.taxOnInterest = Math.round((this.interestApplied * this.gstVatRateOnInterest) / 100);
        } else {
            this.taxOnInterest = 0;
        }
    } else if (fieldName === 'Tax_on_Interest__c') {
        this.taxOnInterest = value;
    }

    // Recalculate excess payment whenever any dependent field changes
    this.calculateExcessPayment();
}

calculatePrincipalApplied(){
    if(this.amountPaid === 0){
        this.principalFloat = 0;
    }
    if(this.amountPaid != undefined && this.amountPaid > 0 && this.amountPaid <= this.fixedOutstandingPrincipal){
     this.principalFloat = this.amountPaid || 0;
    }else if(this.amountPaid != undefined && this.amountPaid > 0 && this.amountPaid > this.fixedOutstandingPrincipal){
        this.principalFloat = this.fixedOutstandingPrincipal || 0;
    }
}
//Calculate remaining principal from amount paid.
calculateRemainingPrincipal() {
    const paid = Number(this.principalFloat) || 0;
    const outstanding = Number(this.fixedOutstandingPrincipal) || 0;

    if (paid >= outstanding) {
        this.remainingPrincipalValue = 0;
    } else {
        this.remainingPrincipalValue = +(outstanding - paid).toFixed(2);
    }
}


calculateExcessPayment() {
    const amountPaid = parseFloat(this.amountPaid) || 0;
    const principal = parseFloat(this.principalFloat) || 0;
    const interest = parseFloat(this.interestApplied) || 0;
    const tax = parseFloat(this.taxOnInterest) || 0;

    let excess = amountPaid - (principal + interest + tax);
    this.excessPayment = excess > 0 ? excess : 0;
    console.log('this.amountPaid-> ', this.amountPaid);
    console.log('this.pricipalFLoat-> ',this.principalFloat);
    console.log('this.interestApplied-> ', this.interestApplied);
    console.log('this.interestApplied', this.interestApplied);
    console.log('this.excessPayment-> ', this.excessPayment);
}


handleInterestAppliedChange(event) {
    this.interestApplied = parseFloat(event.target.value) || 0;

    if (this.interestApplied > 0 && this.gstVatRateOnInterest > 0) {
        const interest = parseFloat(this.interestApplied);
        const gstRate = parseFloat(this.gstVatRateOnInterest);
        const taxValue = (interest * gstRate) / 100;

        // Truncate (not round) to 2 decimal places
        this.taxOnInterest = Math.trunc(taxValue * 100) / 100;
        console.log('Tax on Interest:', this.taxOnInterest);
    } else {
        this.taxOnInterest = 0;
    }

    this.calculateExcessPayment();
}


// Wire to fetch Demand record fields1,32,443.42
@wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_FIELD, BOOKINGPAYMENTSCH_FIELD] })
wiredDemand({ error, data }) {
    if (data) {
        this.accountId = data.fields.Account__c?.value;
        this.bookingPaymentScheduleId = data.fields.Booking_Payment_Schedule_Id__c?.value;
        this.formReady = true; // show form
    } else if (error) {
        console.error('Error fetching Demand record:', error);
    }
}
// Wire to fetch Booking Payment Schedule's OUTSTANDING_PRINCIPAL_FIELD field & GST_VAT_RATE_ON_INTEREST_FIELD
@wire(getRecord, { recordId: '$bookingPaymentScheduleId', fields: [OUTSTANDING_PRINCIPAL_FIELD, GST_VAT_RATE_ON_INTEREST_FIELD] })
wiredOutstandingPrincipal({ error, data }) {
if (data) {
    this.fixedOutstandingPrincipal = data.fields.Outstanding_Principal__c.value;
    this.remainingPrincipalValue = data.fields.Outstanding_Principal__c.value;
    this.gstVatRateOnInterest = data.fields.GST_VAT_Rate_On_Interest__c.value;
} else if (error) {
    console.error('Error fetching Booking Payment Schedule:', error);
}
}

handleSubmit(event) {
    this.isSubmitting = true;
    this.loading = true;
    event.preventDefault(); // prevent default submit
    const fields = event.detail.fields;
    // Parse numeric values safely (convert null/undefined to 0)
    const principalApplied = parseFloat(fields.Principal_Applied__c || 0);
    const interestApplied = parseFloat(fields.Interest_Applied__c || 0);
    const taxOnInterest = parseFloat(fields.Tax_on_Interest__c || 0);
    const excessPayment = parseFloat(fields.Excess_Payment__c || 0);
    const amountPaid = parseFloat(fields.Amount_Paid__c || 0);

    
    console.log('amountPaid : ', amountPaid);
    console.log('principalApplied : ', principalApplied);
    console.log('interestApplied : ', interestApplied);
    console.log('taxOnInterest : ', taxOnInterest);
    
    // Calculate total
    const calculatedTotal = principalApplied + interestApplied + taxOnInterest + excessPayment;
    console.log('calculatedTotal : ', calculatedTotal);

    // Compare with Amount Paid (using a small tolerance to handle float precision)
    if (Math.abs(calculatedTotal - amountPaid) > 0.01) {
        this.isSubmitting = false;
        this.loading = false
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Validation Error',
                message: `The sum of Principal Applied (${principalApplied}), Interest Applied (${interestApplied}), Tax on Interest (${taxOnInterest}), and Excess Payment (${excessPayment}) must be equal to Amount Paid (${amountPaid}).`,
                variant: 'error'
            })
        );
        return; // Stop the submission
    }

    // Prefill the lookup fields
    fields.Demand__c = this.recordId;
    fields.Account__c = this.accountId;
    fields.Booking_Payment_Schedule__c = this.bookingPaymentScheduleId;
    fields.Principal_Applied__c = this.principalFloat;

    // Proceed with save
    this.template.querySelector('lightning-record-edit-form').submit(fields);
}


handleSuccess(event) {
    this.isSubmitting = true;
    this.loading = false;
    //Capture newly created Payment Receipt record Id
    const receiptRecordId = event.detail.id;

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Success',
            message: 'Payment Receipt created successfully!',
            variant: 'success'
        })
    );
    this.dispatchEvent(new CloseActionScreenEvent());
    
    //Navigate to newly created payment receipt record.
    this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
            recordId: receiptRecordId,
            objectApiName: 'Payment_Receipt__c',
            actionName: 'view'
        }
    })
    
}

handleError(event) {
    console.log(' error detected inside handle error');
    this.isSubmitting = false;
    this.loading = false;

    console.error('Error creating Payment Receipt:', JSON.stringify(event.detail));

    let errorMessage = 'Error creating Payment Receipt';

    // Case 1: Field-level validation error
    if (event.detail && event.detail.output && event.detail.output.fieldErrors) {
        const fieldErrors = event.detail.output.fieldErrors;
        const allErrors = Object.values(fieldErrors).flat();
        if (allErrors.length > 0) {
            errorMessage = allErrors.map(e => e.message).join(' ');
        }
    }

    // Case 2: Page-level (record) validation error
    else if (event.detail && event.detail.output && event.detail.output.errors) {
        const pageErrors = event.detail.output.errors;
        if (pageErrors.length > 0) {
            errorMessage = pageErrors.map(e => e.message).join(' ');
        }
    }

    // Case 3: fallback
    else if (event.detail && event.detail.message) {
        errorMessage = event.detail.message;
    }

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Error',
            message: errorMessage,
            variant: 'error'
        })
    );
}


handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
}
}