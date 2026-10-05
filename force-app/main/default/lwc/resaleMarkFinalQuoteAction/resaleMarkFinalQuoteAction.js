import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import submitForApproval from '@salesforce/apex/ResaleQuoteApprovalController.submitForApproval';

import SIMULATION_STATUS from '@salesforce/schema/Quote.Simulation_Status__c';
import FINAL_QUOTE from '@salesforce/schema/Quote.Final_Quote__c';

const FIELDS = [SIMULATION_STATUS, FINAL_QUOTE];

export default class ResaleMarkFinalQuoteAction extends LightningElement {
    @api recordId;

    isLoading = false;
    isDone = false;
    errorMessage = '';
    successMessage = '';
    remarks = '';

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    quoteRecord;

    get simulationStatus() {
        return getFieldValue(this.quoteRecord.data, SIMULATION_STATUS);
    }

    get isAlreadyApproved() {
        return this.simulationStatus === 'Approved';
    }

    get isAlreadySubmitted() {
        return this.simulationStatus === 'Submitted';
    }

    get isNotFinalQuote() {
        return this.quoteRecord.data && !getFieldValue(this.quoteRecord.data, FINAL_QUOTE);
    }

    get isWiring() {
        return !this.quoteRecord.data && !this.quoteRecord.error && !this.isLoading && !this.isDone;
    }

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    handleSubmit() {
        this.isLoading = true;
        this.errorMessage = '';

        submitForApproval({ quoteId: this.recordId, remarks: this.remarks })
            .then(result => {
                this.isLoading = false;
                this.isDone = true;
                this.successMessage = result === 'submitted'
                    ? 'Quote submitted for approval. The approver will receive an email with full commercial details.'
                    : 'Quote marked as submitted. An approval email has been sent with the full commercial breakdown.';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Submitted for Approval',
                    message: this.successMessage,
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = error?.body?.message || error?.message || 'An unexpected error occurred.';
            });
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}