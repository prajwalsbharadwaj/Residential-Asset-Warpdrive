import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getLedgerSummary from '@salesforce/apex/CustomerLedgerController.getLedgerSummary';
import getInstallments from '@salesforce/apex/CustomerLedgerController.getInstallments';

export default class StatementOfAccountModal extends LightningElement {
    _recordId;
    @track isLoading = true;
    @track summary = {};
    @track rawMilestones = [];

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(val) {
        this._recordId = val;
        if (val) {
            this.loadAccountStatement();
        }
    }

    connectedCallback() {
        if (this._recordId) {
            this.loadAccountStatement();
        }
    }

    async loadAccountStatement() {
        if (!this._recordId) {
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        try {
            const [sumData, milData] = await Promise.all([
                getLedgerSummary({ recordId: this._recordId }),
                getInstallments({ bookingId: this._recordId })
            ]);
            this.summary = sumData || {};
            this.rawMilestones = milData || [];
        } catch (error) {
            console.error('Error loading statement of account:', error);
            this.showToast('Error Loading Statement of Account', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get currentDate() {
        return new Date().toLocaleDateString('en-GB', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });
    }

    get formattedAgreementValue() {
        return this.formatNumber(this.summary.agreementValue);
    }

    get formattedTotalDemanded() {
        return this.formatNumber(this.summary.totalDemanded);
    }

    get formattedTotalReceived() {
        return this.formatNumber(this.summary.totalReceived);
    }

    get formattedOutstandingPrincipal() {
        return this.formatNumber(this.summary.outstandingPrincipal);
    }

    get formattedOverdueInterest() {
        return this.formatNumber(this.summary.totalOverdueInterest);
    }

    get formattedNetPayable() {
        return this.formatNumber(this.summary.netPayableToday);
    }

    get processedMilestones() {
        return (this.rawMilestones || []).map((m) => {
            const hasInterest = (m.overdueInterest || 0) > 0;
            let badgeClass = 'status-badge status-upcoming';
            if (m.status === 'Paid') badgeClass = 'status-badge status-paid';
            else if (m.status === 'Overdue') badgeClass = 'status-badge status-overdue';
            else if (m.status === 'Demanded') badgeClass = 'status-badge status-demanded';

            return {
                ...m,
                dueDateFormatted: m.dueDate ? new Date(m.dueDate).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '-',
                formattedAmount: this.formatNumber(m.amount),
                formattedPaid: this.formatNumber(m.paidAmount),
                formattedDue: this.formatNumber(m.outstandingAmount),
                formattedInterest: this.formatNumber(m.overdueInterest),
                hasInterest,
                badgeClass
            };
        });
    }

    formatNumber(val) {
        if (!val) return '0.00';
        return Number(val).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    handlePrint() {
        window.print();
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
