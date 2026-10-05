import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getAllotmentLetterData from '@salesforce/apex/CustomerLedgerController.getAllotmentLetterData';
import sendAllotmentLetterEmail from '@salesforce/apex/CustomerLedgerController.sendAllotmentLetterEmail';

export default class AllotmentLetterModal extends LightningElement {
    _recordId;
    @track isLoading = true;
    @track isSendingEmail = false;
    @track letterData = {};

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(val) {
        this._recordId = val;
        if (val) {
            this.loadLetterData();
        }
    }

    connectedCallback() {
        if (this._recordId) {
            this.loadLetterData();
        }
    }

    async loadLetterData() {
        if (!this._recordId) {
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        try {
            const data = await getAllotmentLetterData({ bookingId: this._recordId });
            this.letterData = data || {};
        } catch (error) {
            console.error('Error loading allotment letter data:', error);
            this.showToast('Error Loading Allotment Letter', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get formattedAgreementValue() {
        return this.formatPrice(this.letterData?.agreementValue);
    }

    get formattedTokenPaid() {
        return this.formatPrice(this.letterData?.tokenAmountPaid);
    }

    get formattedBalanceDue() {
        return this.formatPrice(this.letterData?.balanceDue);
    }

    handlePrint() {
        window.print();
    }

    async handleSendEmail() {
        if (!this._recordId) return;
        this.isSendingEmail = true;
        try {
            const res = await sendAllotmentLetterEmail({ bookingId: this._recordId });
            if (res && res.success) {
                this.showToast('Email Dispatched', res.message, 'success');
            } else {
                this.showToast('Email Error', res?.message || 'Could not dispatch email.', 'error');
            }
        } catch (error) {
            console.error('Error sending allotment letter email:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isSendingEmail = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    formatPrice(val) {
        if (!val && val !== 0) return '0.00';
        return Number(val).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
