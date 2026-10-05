import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import getStatus         from '@salesforce/apex/ResaleKycLinkController.getStatus';
import generateAndSend   from '@salesforce/apex/ResaleKycLinkController.generateAndSendLink';
import reopenForm        from '@salesforce/apex/ResaleKycLinkController.reopenForm';

export default class ResaleKycLinkAction extends NavigationMixin(LightningElement) {
    @api recordId;
    @api isScreenAction = false;

    status  = null;
    loading = true;
    error   = null;
    busy    = false;
    confirmRegenerate = false;

    @wire(getStatus, { opportunityId: '$recordId' })
    wiredStatus({ data, error }) {
        this.loading = false;
        if (data) {
            this.status = data;
        } else if (error) {
            this.error = error.body?.message || 'Failed to load KYC status.';
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    get hasLink()      { return !!this.status?.url; }
    get isSubmitted()  { return this.status?.status === 'Submitted'; }
    get showStatus()   { return !this.loading && this.status; }
    get showActions()  { return !this.confirmRegenerate && this.status && !this.loading; }

    get statusClass() {
        const s = this.status?.status;
        if (s === 'Submitted')      return 'badge badge--green';
        if (s === 'In Progress')    return 'badge badge--blue';
        if (s === 'Link Generated') return 'badge badge--orange';
        return 'badge';
    }

    get expiredClass() {
        return this.status?.expired ? 'text-danger' : '';
    }

    get expiresLabel() {
        if (!this.status?.expiresOn) return '';
        const d = new Date(this.status.expiresOn);
        const label = d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
        return this.status.expired ? label + ' (Expired)' : label;
    }

    get submittedAtFormatted() {
        return this._fmt(this.status?.submittedAt);
    }

    get lastSavedAtFormatted() {
        return this._fmt(this.status?.lastSavedAt);
    }

    _fmt(dt) {
        if (!dt) return '';
        return new Date(dt).toLocaleString('en-IN', { day:'2-digit', month:'short', year:'numeric', hour:'2-digit', minute:'2-digit' });
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    handleGenerate() {
        if (this.hasLink && !this.isSubmitted) {
            this.confirmRegenerate = true;
        } else {
            this.doGenerate();
        }
    }

    cancelRegenerate() {
        this.confirmRegenerate = false;
    }

    async doGenerate() {
        this.busy = true;
        this.error = null;
        this.confirmRegenerate = false;
        try {
            this.status = await generateAndSend({ opportunityId: this.recordId });
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            // Immediately open the KYC form in a new tab
            if (this.status?.url) {
                window.open(this.status.url, '_blank', 'noopener,noreferrer');
                this.dispatchEvent(new CloseActionScreenEvent());
            }
        } catch(e) {
            this.error = e.body?.message || 'Failed to generate KYC link.';
        } finally {
            this.busy = false;
        }
    }

    async handleReopen() {
        this.busy = true;
        this.error = null;
        try {
            this.status = await reopenForm({ opportunityId: this.recordId });
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch(e) {
            this.error = e.body?.message || 'Failed to reopen form.';
        } finally {
            this.busy = false;
        }
    }
}