import { LightningElement, api } from 'lwc';
import createInterestWaiverRequest from '@salesforce/apex/InterestWaiverController.createInterestWaiverRequest';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class InterestWaiverApprovalButton extends LightningElement {
    @api recordId; // Booking_Payment_Schedule__c ID

    waiverAmount;
    waiverReason;
    waiverScope = 'Installment'; // Hardcoded

    connectedCallback() {
        // You can log or validate further if needed
    }

    get isSaveDisabled() {
        return !(this.waiverAmount && this.waiverReason);
    }

    handleChange(event) {
        const field = event.target.dataset.id;
        if (field === 'waiverAmount') {
            this.waiverAmount = event.target.value;
        } else if (field === 'waiverReason') {
            this.waiverReason = event.target.value;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        createInterestWaiverRequest({
            bookingPaymentScheduleId: this.recordId,
            waiverAmount: parseFloat(this.waiverAmount),
            waiverReason: this.waiverReason,
            waiverScope: this.waiverScope
        })
        .then(() => {
            this.showToast('Success', 'Interest Waiver Request submitted for approval.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        })
        .catch((error) => {
            this.showToast('Error', this.parseError(error), 'error');
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    parseError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        return 'An unexpected error occurred.';
    }
}