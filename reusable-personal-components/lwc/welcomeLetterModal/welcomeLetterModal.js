import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getWelcomeLetterData from '@salesforce/apex/CustomerLedgerController.getWelcomeLetterData';
import sendWelcomeLetterEmail from '@salesforce/apex/CustomerLedgerController.sendWelcomeLetterEmail';

export default class WelcomeLetterModal extends LightningElement {
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
            this.loadWelcomeData();
        }
    }

    connectedCallback() {
        if (this._recordId) {
            this.loadWelcomeData();
        }
    }

    async loadWelcomeData() {
        if (!this._recordId) {
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        try {
            const data = await getWelcomeLetterData({ recordId: this._recordId });
            this.letterData = data || {};
        } catch (error) {
            console.error('Error loading welcome letter data:', error);
            this.showToast('Error Loading Welcome Letter', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handlePrint() {
        window.print();
    }

    async handleSendEmail() {
        if (!this._recordId) return;
        this.isSendingEmail = true;
        try {
            const res = await sendWelcomeLetterEmail({ opportunityId: this._recordId });
            if (res && res.success) {
                this.showToast('Welcome Package Sent', res.message, 'success');
                this.handleClose();
            } else {
                this.showToast('Email Error', res?.message || 'Could not dispatch email.', 'error');
            }
        } catch (error) {
            console.error('Error sending welcome letter email:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isSendingEmail = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
