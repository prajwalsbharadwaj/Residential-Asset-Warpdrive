import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getHandoverContext from '@salesforce/apex/HandoverWorkspaceController.getHandoverContext';

export default class HandoverActionAuditor extends LightningElement {
    @api recordId;
    isLoading = true;
    externalInspectionUrl = null;

    connectedCallback() {
        this.loadAuditorLink();
    }

    async loadAuditorLink() {
        try {
            const data = await getHandoverContext({ handoverId: this.recordId });
            if (data && data.externalInspectionUrl) {
                this.externalInspectionUrl = data.externalInspectionUrl;
            }
        } catch (e) {
            console.error('Error loading auditor link', e);
        } finally {
            this.isLoading = false;
        }
    }

    get fullUrl() {
        if (!this.externalInspectionUrl) return '';
        if (this.externalInspectionUrl.startsWith('http')) return this.externalInspectionUrl;
        return window.location.origin + this.externalInspectionUrl;
    }

    handleCopyLink() {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(this.fullUrl);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copied',
                message: 'Auditor link copied to clipboard.',
                variant: 'success'
            }));
        }
    }

    handleOpenLink() {
        window.open(this.fullUrl, '_blank');
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new CustomEvent('close'));
    }
}
