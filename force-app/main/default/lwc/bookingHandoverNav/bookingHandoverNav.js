import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getHandoverSummaryForBooking from '@salesforce/apex/HandoverWorkspaceController.getHandoverSummaryForBooking';
import getOrCreateHandoverForBooking from '@salesforce/apex/HandoverWorkspaceController.getOrCreateHandoverForBooking';

export default class BookingHandoverNav extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isLoading = true;
    @track isCreating = false;
    @track summary = null;
    @track targetDateInput = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    @track customerSigneeInput = '';
    @track instructionsInput = '';

    connectedCallback() {
        this.loadSummary();
    }

    handleTargetDateChange(event) {
        this.targetDateInput = event.target.value;
    }

    handleCustomerSigneeChange(event) {
        this.customerSigneeInput = event.target.value;
    }

    handleInstructionsChange(event) {
        this.instructionsInput = event.target.value;
    }

    async loadSummary() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            const data = await getHandoverSummaryForBooking({ bookingId: this.recordId });
            this.summary = data;
        } catch (error) {
            console.error('Error loading handover summary for booking:', error);
            this.summary = null;
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadSummary();
    }

    get hasHandover() {
        return Boolean(this.summary && this.summary.exists && this.summary.handoverId);
    }

    get targetDateDisplay() {
        return this.summary?.targetDateFormatted || (this.summary?.targetDate ? String(this.summary.targetDate) : 'Not Scheduled');
    }

    get stageLabel() {
        const s = this.summary?.stage;
        if (s === 'Readiness') return '1. Readiness Gate';
        if (s === 'Inspection') return '2. Inspection';
        if (s === 'Resolution') return '3. Snag Resolution';
        if (s === 'Appointment') return '4. Appointment';
        if (s === 'Completed') return '5. Completed';
        return s || 'Readiness';
    }

    get stageBadgeClass() {
        const s = this.summary?.stage;
        if (s === 'Completed') return 'slds-badge slds-theme_success';
        if (s === 'Appointment') return 'slds-badge slds-theme_warning';
        return 'slds-badge slds-theme_info';
    }

    navigateToHandover() {
        if (!this.summary?.handoverId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.summary.handoverId,
                objectApiName: 'Handover__c',
                actionName: 'view'
            }
        });
    }

    async initiateHandover() {
        if (!this.recordId || this.isCreating) return;
        this.isCreating = true;
        try {
            const handoverId = await getOrCreateHandoverForBooking({ bookingId: this.recordId });
            if (handoverId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Handover Initiated',
                        message: 'Handover record created successfully. Redirecting to Handover Workspace...',
                        variant: 'success'
                    })
                );
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: handoverId,
                        objectApiName: 'Handover__c',
                        actionName: 'view'
                    }
                });
            } else {
                throw new Error('Could not create Handover record.');
            }
        } catch (error) {
            console.error('Error initiating handover:', error);
            const msg = error?.body?.message || error?.message || 'Failed to initiate Handover.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Initiation Failed',
                    message: msg,
                    variant: 'error'
                })
            );
        } finally {
            this.isCreating = false;
        }
    }
}
