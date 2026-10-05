import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import getArchiveInfo from '@salesforce/apex/LeadArchiveService.getArchiveInfo';
import completeFollowUp from '@salesforce/apex/LeadArchiveService.completeFollowUp';
import sendFollowUpNotification from '@salesforce/apex/LeadArchiveService.sendFollowUpNotification';

export default class LeadArchiveBanner extends LightningElement {
    @api recordId;

    @track isLoading = true;
    @track isArchived = false;
    @track isFollowUpDue = false;
    @track archiveDays = null;
    @track followUpDate = null;
    @track statusText = '';
    @track leadName = '';

    @track isCustomModalOpen = false;
    @track customDaysInput = null;

    connectedCallback() {
        this.loadStatus();
    }

    async loadStatus() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            const data = await getArchiveInfo({ leadId: this.recordId });
            this.isArchived = data.isArchived;
            this.isFollowUpDue = data.isFollowUpDue;
            this.archiveDays = data.archiveDays;
            this.followUpDate = data.followUpDate;
            this.statusText = data.statusText;
            this.leadName = data.leadName;
        } catch (e) {
            console.error('Error fetching archive info:', e);
        } finally {
            this.isLoading = false;
        }
    }

    get isIdle() {
        return !this.isArchived && !this.isFollowUpDue;
    }

    get formattedFollowUpDate() {
        if (!this.followUpDate) return '';
        const d = new Date(this.followUpDate);
        return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
    }

    get isSaveDisabled() {
        return !this.customDaysInput || Number(this.customDaysInput) <= 0;
    }

    async handleQuickArchive(event) {
        const days = Number(event.target.dataset.days);
        await this.saveArchiveDays(days);
    }

    handleOpenCustomModal() {
        this.customDaysInput = this.archiveDays || 45;
        this.isCustomModalOpen = true;
    }

    handleCloseCustomModal() {
        this.isCustomModalOpen = false;
    }

    handleDaysInputChange(event) {
        this.customDaysInput = event.target.value;
    }

    async handleSaveCustomArchive() {
        const days = Number(this.customDaysInput);
        if (days > 0) {
            this.isCustomModalOpen = false;
            await this.saveArchiveDays(days);
        }
    }

    async saveArchiveDays(days) {
        this.isLoading = true;
        try {
            const fields = {
                Id: this.recordId,
                Archive_For_In_Days__c: days
            };
            await updateRecord({ fields });
            this.showToast('Lead Archived', `Follow-up scheduled in ${days} days. You will be notified when customer might be ready.`, 'success');
            await this.loadStatus();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (err) {
                console.warn(err);
            }
        } catch (error) {
            this.showToast('Error Archiving Lead', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    async handleCompleteFollowUp() {
        this.isLoading = true;
        try {
            await completeFollowUp({ leadId: this.recordId });
            this.showToast('Follow-Up Completed!', 'Lead status updated to active.', 'success');
            await this.loadStatus();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (err) {
                console.warn(err);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    async handleMenuSelect(event) {
        const action = event.detail.value;
        if (action === 'trigger_now') {
            this.isLoading = true;
            try {
                await sendFollowUpNotification({ leadId: this.recordId });
                this.showToast('Notification Dispatched! 🔔', 'Alert: "Customer might be ready, follow up" sent to owner with high-priority task created.', 'warning');
                await this.loadStatus();
                try {
                    await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                } catch (err) {
                    console.warn(err);
                }
            } catch (error) {
                this.showToast('Error Dispatching Alert', error.body?.message || error.message, 'error');
                this.isLoading = false;
            }
        } else if (action === 'clear_archive') {
            await this.handleCompleteFollowUp();
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
