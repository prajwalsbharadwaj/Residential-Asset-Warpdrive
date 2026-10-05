import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import getHandoverContext from '@salesforce/apex/HandoverWorkspaceController.getHandoverContext';

export default class HandoverActionProperty extends LightningElement {
    @api recordId;
    isLoading = true;
    unitSummary = {};
    contactSummary = {};

    connectedCallback() {
        this.loadDetails();
    }

    async loadDetails() {
        try {
            const data = await getHandoverContext({ handoverId: this.recordId });
            if (data) {
                this.unitSummary = data.unitSummary || {};
                this.contactSummary = data.contactSummary || {};
            }
        } catch (e) {
            console.error('Error loading details', e);
        } finally {
            this.isLoading = false;
        }
    }

    get phoneHref() {
        return this.contactSummary.phone ? `tel:${this.contactSummary.phone}` : '#';
    }

    get emailHref() {
        return this.contactSummary.email ? `mailto:${this.contactSummary.email}` : '#';
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new CustomEvent('close'));
    }
}
