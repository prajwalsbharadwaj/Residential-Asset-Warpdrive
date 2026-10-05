import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import getLedgerSummary from '@salesforce/apex/CustomerLedgerController.getLedgerSummary';
import getInstallments from '@salesforce/apex/CustomerLedgerController.getInstallments';
import getReceipts from '@salesforce/apex/CustomerLedgerController.getReceipts';
import getCustomerBookings from '@salesforce/apex/CustomerLedgerController.getCustomerBookings';
import requestInterestWaiver from '@salesforce/apex/CustomerLedgerController.requestInterestWaiver';
import reviewInterestWaiver from '@salesforce/apex/CustomerLedgerController.reviewInterestWaiver';
import issueDemandNote from '@salesforce/apex/CustomerLedgerController.issueDemandNote';
import sendDemandReminder from '@salesforce/apex/CustomerLedgerController.sendDemandReminder';
import logDetailedReceipt from '@salesforce/apex/CustomerLedgerController.logDetailedReceipt';
import reconcileReceipt from '@salesforce/apex/CustomerLedgerController.reconcileReceipt';
import clearReceiptInSap from '@salesforce/apex/CustomerLedgerController.clearReceiptInSap';
import postReceiptToLedger from '@salesforce/apex/CustomerLedgerController.postReceiptToLedger';
import recalculateInstallmentBalances from '@salesforce/apex/CustomerLedgerController.recalculateInstallmentBalances';

export default class CustomerLedgerHub extends LightningElement {
    @api recordId;

    @track isLoading = true;
    @track isSubmitting = false;

    // Unit / Booking Selector
    @track bookingOptions = [];
    @track selectedBookingId = null;
    @track hasBooking = true;

    // Financial KPI Summary
    @track summary = {
        agreementValue: 0,
        tokenAmount: 0,
        totalDemanded: 0,
        totalReceived: 0,
        outstandingPrincipal: 0,
        totalOverdueInterest: 0,
        totalInterestWaived: 0,
        netPayableToday: 0,
        unitName: '',
        configuration: '',
        customerName: '',
        bookingName: ''
    };

    // Lists
    @track rawInstallments = [];
    @track rawReceipts = [];

    // Modals
    @track isWaiverModalOpen = false;
    @track selectedInstallmentId = '';
    @track selectedInstallmentName = '';
    @track selectedInstallmentInterest = 0;
    @track selectedInstallmentDaysOverdue = 0;
    @track waiverAmountInput = 0;
    @track waiverReasonInput = '';

    @track isQuickPayModalOpen = false;
    @track selectedPayInstallmentId = '';
    @track paymentAmountInput = 0;
    @track paymentModeInput = 'NEFT/RTGS';
    @track paymentUtrInput = '';
    @track paymentDateInput = new Date().toISOString().slice(0, 10);
    @track instrumentDateInput = new Date().toISOString().slice(0, 10);
    @track instrumentNumberInput = '';
    @track bankNameInput = 'State Bank of India';

    paymentModeOptions = [
        { label: 'NEFT / RTGS Transfer', value: 'NEFT/RTGS' },
        { label: 'Cheque', value: 'Cheque' },
        { label: 'Demand Draft', value: 'Demand Draft' },
        { label: 'UPI Direct', value: 'UPI' },
        { label: 'Credit Card Gateway', value: 'Credit Card' },
        { label: 'Wire Transfer', value: 'Wire Transfer' }
    ];

    connectedCallback() {
        this.loadAllLedgerData();
    }

    async loadAllLedgerData() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            // First load customer bookings if not already loaded or on refresh
            const bookings = await getCustomerBookings({ recordId: this.recordId });
            this.bookingOptions = (bookings || []).map(b => ({
                label: b.label,
                value: b.bookingId,
                unitName: b.unitName,
                projectName: b.projectName,
                status: b.status
            }));

            if (this.bookingOptions.length > 0) {
                const exists = this.bookingOptions.some(b => b.value === this.selectedBookingId);
                if (!this.selectedBookingId || !exists) {
                    this.selectedBookingId = this.bookingOptions[0].value;
                }
            } else {
                this.selectedBookingId = this.recordId;
            }

            const targetId = this.selectedBookingId || this.recordId;
            const [summaryData, instData, rcptData] = await Promise.all([
                getLedgerSummary({ bookingId: targetId }),
                getInstallments({ bookingId: targetId }),
                getReceipts({ bookingId: targetId })
            ]);

            if (summaryData) {
                this.summary = summaryData;
                this.rawInstallments = instData || [];
                this.rawReceipts = rcptData || [];
                this.hasBooking = true;
            } else {
                this.hasBooking = false;
                this.summary = {};
                this.rawInstallments = [];
                this.rawReceipts = [];
            }

        } catch (error) {
            console.error('Error loading ledger data:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleBookingChange(event) {
        this.selectedBookingId = event.detail.value;
        this.loadSelectedBookingLedger();
    }

    async loadSelectedBookingLedger() {
        if (!this.selectedBookingId) return;
        this.isLoading = true;
        try {
            const [summaryData, instData, rcptData] = await Promise.all([
                getLedgerSummary({ bookingId: this.selectedBookingId }),
                getInstallments({ bookingId: this.selectedBookingId }),
                getReceipts({ bookingId: this.selectedBookingId })
            ]);

            if (summaryData) {
                this.summary = summaryData;
                this.rawInstallments = instData || [];
                this.rawReceipts = rcptData || [];
                this.hasBooking = true;
            } else {
                this.hasBooking = false;
            }
        } catch (error) {
            console.error('Error loading selected booking ledger:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get hasMultipleBookings() {
        return this.bookingOptions && this.bookingOptions.length > 1;
    }

    async handleRefreshLedger() {
        await this.loadAllLedgerData();
        this.showToast('Refreshed', 'Customer financial ledger synchronized.', 'info');
    }

    // Computed Getters for formatted values
    get formattedAgreementValue() { return this.formatPrice(this.summary.agreementValue); }
    get formattedTokenAmount() { return this.formatPrice(this.summary.tokenAmount); }
    get formattedTotalDemanded() { return this.formatPrice(this.summary.totalDemanded); }
    get formattedTotalReceived() { return this.formatPrice(this.summary.totalReceived); }
    get formattedOutstandingPrincipal() { return this.formatPrice(this.summary.outstandingPrincipal); }
    get formattedOverdueInterest() { return this.formatPrice(this.summary.totalOverdueInterest); }
    get formattedNetPayableToday() { return this.formatPrice(this.summary.netPayableToday); }
    get installmentsCount() { return this.rawInstallments.length; }

    get installmentsList() {
        return this.rawInstallments.map(inst => {
            let statusClass = 'status-pill ';
            if (inst.status === 'Paid') statusClass += 'status-paid';
            else if (inst.status === 'Overdue') statusClass += 'status-overdue';
            else if (inst.status === 'Due') statusClass += 'status-due';
            else statusClass += 'status-upcoming';

            let waiverClass = 'waiver-pill ';
            if (inst.waiverStatus === 'Approved') waiverClass += 'waiver-approved';
            else if (inst.waiverStatus === 'Requested') waiverClass += 'waiver-requested';
            else if (inst.waiverStatus === 'Rejected') waiverClass += 'waiver-rejected';

            let remClass = 'reminder-pill ';
            if (inst.demandReminderLevel === 'Reminder 1 (15 Days)') remClass += 'reminder-level-1';
            else if (inst.demandReminderLevel === 'Reminder 2 (30 Days)') remClass += 'reminder-level-2';
            else if (inst.demandReminderLevel === 'Final Notice (45 Days)') remClass += 'reminder-level-3';
            else remClass += 'reminder-level-none';

            return {
                ...inst,
                formattedAmount: this.formatPrice(inst.amount),
                formattedPaidAmount: this.formatPrice(inst.paidAmount),
                formattedOutstandingAmount: this.formatPrice(inst.outstandingAmount),
                formattedOverdueInterest: this.formatPrice(inst.overdueInterest),
                formattedDueDate: inst.dueDate ? this.formatDate(inst.dueDate) : '-',
                formattedDemandDate: inst.demandNoteDate ? this.formatDate(inst.demandNoteDate) : '',
                hasInterest: inst.overdueInterest > 0,
                statusBadgeClass: statusClass,
                waiverBadgeClass: waiverClass,
                hasWaiverActivity: inst.waiverStatus && inst.waiverStatus !== 'None',
                canRequestWaiver: inst.overdueInterest > 0 && (!inst.waiverStatus || inst.waiverStatus === 'None' || inst.waiverStatus === 'Rejected'),
                isPaid: inst.status === 'Paid',
                hasSapInvoice: Boolean(inst.sapInvoiceNumber),
                canSendReminder: inst.hasDemandNote && inst.status !== 'Paid',
                reminderBadgeClass: remClass,
                formattedTdsAmount: this.formatPrice(inst.tdsAmount),
                formattedNetPayable: this.formatPrice(inst.netPayableToBuilder),
                isTdsApplicable: Boolean(inst.isTdsApplicable)
            };
        });
    }

    get receiptsList() {
        return this.rawReceipts.map(r => {
            let statusClass = 'status-pill ';
            if (r.status === 'Confirmed') statusClass += 'status-paid';
            else if (r.status === 'Pending Reconciliation') statusClass += 'reconcile-pending-badge';
            else if (r.status === 'SAP Cleared') statusClass += 'sap-invoice-badge';
            else statusClass += 'status-overdue';

            return {
                ...r,
                formattedAmount: this.formatPrice(r.amount),
                formattedReceiptDate: r.receiptDate ? this.formatDate(r.receiptDate) : '-',
                formattedInstrumentDate: r.instrumentDate ? this.formatDate(r.instrumentDate) : '-',
                formattedSapReconciledDate: r.sapReconciledDate ? this.formatDate(r.sapReconciledDate) : '-',
                statusBadgeClass: statusClass,
                isPendingReconciliation: r.status === 'Pending Reconciliation',
                isSapCleared: r.status === 'SAP Cleared',
                isConfirmed: r.status === 'Confirmed'
            };
        });
    }

    get waiverInstallmentsList() {
        return this.rawInstallments
            .filter(inst => inst.waiverStatus && inst.waiverStatus !== 'None')
            .map(w => {
                let waiverClass = 'waiver-pill ';
                if (w.waiverStatus === 'Approved') waiverClass += 'waiver-approved';
                else if (w.waiverStatus === 'Requested') waiverClass += 'waiver-requested';
                else if (w.waiverStatus === 'Rejected') waiverClass += 'waiver-rejected';

                return {
                    ...w,
                    formattedOverdueInterest: this.formatPrice(w.overdueInterest),
                    formattedWaivedAmount: this.formatPrice(w.waivedInterestAmount),
                    formattedWaiverDate: w.waiverRequestedDate ? this.formatDate(w.waiverRequestedDate) : '-',
                    waiverBadgeClass: waiverClass,
                    isPendingReview: w.waiverStatus === 'Requested'
                };
            });
    }

    get hasWaiverRequests() {
        return this.waiverInstallmentsList.length > 0;
    }

    get installmentOptions() {
        return this.rawInstallments
            .filter(inst => inst.status !== 'Paid')
            .map(inst => ({
                label: `${inst.milestoneName} (Due: ₹${this.formatPrice(inst.outstandingAmount)})`,
                value: inst.id
            }));
    }

    // Modal Handlers: Interest Waiver Request
    handleOpenWaiverModal(event) {
        const id = event.target.dataset.id;
        const target = this.rawInstallments.find(i => i.id === id);
        if (!target) return;

        this.selectedInstallmentId = target.id;
        this.selectedInstallmentName = target.milestoneName;
        this.selectedInstallmentInterest = this.formatPrice(target.overdueInterest);
        this.selectedInstallmentDaysOverdue = target.daysOverdue;
        this.waiverAmountInput = target.overdueInterest;
        this.waiverReasonInput = '';
        this.isWaiverModalOpen = true;
    }

    handleCloseWaiverModal() {
        this.isWaiverModalOpen = false;
    }

    handleWaiverAmountChange(event) {
        this.waiverAmountInput = event.detail.value;
    }

    handleWaiverReasonChange(event) {
        this.waiverReasonInput = event.detail.value;
    }

    handleSetFullWaiver() {
        const target = this.rawInstallments.find(i => i.id === this.selectedInstallmentId);
        if (target) {
            this.waiverAmountInput = target.overdueInterest;
        }
    }

    handleSelectReasonChip(event) {
        const reason = event.target.dataset.reason;
        if (this.waiverReasonInput) {
            this.waiverReasonInput = `${this.waiverReasonInput} • ${reason}`;
        } else {
            this.waiverReasonInput = reason;
        }
    }

    async handleSubmitWaiverRequest() {
        if (!this.waiverAmountInput || this.waiverAmountInput <= 0) {
            this.showToast('Validation Error', 'Please enter a valid waiver amount.', 'warning');
            return;
        }
        if (!this.waiverReasonInput) {
            this.showToast('Validation Error', 'Please provide a business reason for the waiver request.', 'warning');
            return;
        }

        this.isSubmitting = true;
        try {
            const res = await requestInterestWaiver({
                installmentId: this.selectedInstallmentId,
                waiverAmount: Number(this.waiverAmountInput),
                reason: this.waiverReasonInput
            });

            this.showToast('Waiver Requested', res.message, 'success');
            this.isWaiverModalOpen = false;
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // Finance Persona: Approve / Reject Actions
    async handleApproveWaiver(event) {
        const id = event.target.dataset.id;
        this.isLoading = true;
        try {
            const res = await reviewInterestWaiver({
                installmentId: id,
                approve: true,
                remarks: 'Approved by Finance Executive as per customer relationship policy.'
            });
            this.showToast('Waiver Approved!', res.message, 'success');
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    async handleRejectWaiver(event) {
        const id = event.target.dataset.id;
        this.isLoading = true;
        try {
            const res = await reviewInterestWaiver({
                installmentId: id,
                approve: false,
                remarks: 'Rejected by Finance Executive due to policy threshold.'
            });
            this.showToast('Waiver Rejected', res.message, 'info');
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    // Demand Note Generation
    async handleIssueDemandNote(event) {
        const id = event.target.dataset.id;
        this.isLoading = true;
        try {
            const res = await issueDemandNote({ installmentId: id });
            this.showToast('Demand Note Issued', res.message, 'success');
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    handleViewDemandNote(event) {
        const id = event.target.dataset.id;
        const inst = this.rawInstallments.find(i => i.id === id);
        if (inst) {
            const sapMsg = inst.sapInvoiceNumber ? ` | SAP Invoice: ${inst.sapInvoiceNumber} (Block Released)` : '';
            this.showToast('Demand Note Details', `Demand Note ${inst.demandNoteNumber} issued on ${inst.demandNoteDate} for milestone ${inst.milestoneName}${sapMsg}`, 'info');
        }
    }

    // Demand Payment Reminders Dispatch (15d, 30d, 45d)
    async handleSendReminderMenu(event) {
        const id = event.target.dataset.id;
        const level = parseInt(event.target.dataset.level || '1', 10);
        this.isLoading = true;
        try {
            const res = await sendDemandReminder({ installmentId: id, reminderLevel: level });
            this.showToast('Reminder Dispatched', res.message, 'success');
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error Sending Reminder', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    // Ledger Recalculation & Reconciliation
    async handleRecalculateLedger() {
        const targetId = this.selectedBookingId || this.recordId;
        if (!targetId) return;
        this.isLoading = true;
        try {
            const res = await recalculateInstallmentBalances({ bookingId: targetId });
            this.showToast('Ledger Reconciled', res.message, 'success');
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: targetId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Recalculation Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    // Step 1: SAP Persona verifies bank credit
    async handleSapClearReceipt(event) {
        const id = event.target.dataset.id;
        const sapDoc = 'SAP-CLR-' + Math.floor(10000 + Math.random() * 90000);
        this.isLoading = true;
        try {
            const res = await clearReceiptInSap({
                receiptId: id,
                sapDocNumber: sapDoc,
                notes: 'Bank credit line cleared via SAP bank feeder.'
            });
            this.showToast('SAP Cleared', res.message, 'success');
            await this.loadAllLedgerData();
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    // Step 2: Finance Persona approves & posts to Ledger
    async handleFinancePostReceipt(event) {
        const id = event.target.dataset.id;
        this.isLoading = true;
        try {
            const res = await postReceiptToLedger({
                receiptId: id,
                approve: true,
                notes: 'Finance Persona approved and posted credit to Customer Ledger.'
            });
            this.showToast('Receipt Confirmed & Posted', res.message, 'success');
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    // Legacy / Direct Reconcile & Clear handler
    async handleApproveReceipt(event) {
        const id = event.target.dataset.id;
        this.isLoading = true;
        try {
            const res = await reconcileReceipt({ receiptId: id, approve: true, notes: 'Cleared in SAP bank statement reconciliation.' });
            this.showToast('Receipt Confirmed', res.message, 'success');
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    async handleRejectReceipt(event) {
        const id = event.target.dataset.id;
        this.isLoading = true;
        try {
            const res = await reconcileReceipt({ receiptId: id, approve: false, notes: 'Rejected by Finance during SAP bank statement reconciliation.' });
            this.showToast('Receipt Rejected', res.message, 'warning');
            await this.loadAllLedgerData();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    // Modal Handlers: Record Detailed Payment Receipt
    handleOpenQuickPayModal() {
        const unpaid = this.rawInstallments.find(i => i.status !== 'Paid');
        if (unpaid) {
            this.selectedPayInstallmentId = unpaid.id;
            this.paymentAmountInput = unpaid.outstandingAmount;
        } else {
            this.selectedPayInstallmentId = '';
            this.paymentAmountInput = 0;
        }
        this.paymentUtrInput = 'HDFC-N' + Math.floor(10000000 + Math.random() * 90000000);
        this.instrumentNumberInput = this.paymentUtrInput;
        this.bankNameInput = 'State Bank of India';
        this.instrumentDateInput = new Date().toISOString().slice(0, 10);
        this.paymentDateInput = new Date().toISOString().slice(0, 10);
        this.isQuickPayModalOpen = true;
    }

    handleRowPay(event) {
        const id = event.target.dataset.id;
        const inst = this.rawInstallments.find(i => i.id === id);
        if (inst) {
            this.selectedPayInstallmentId = inst.id;
            this.paymentAmountInput = inst.outstandingAmount;
            this.paymentUtrInput = 'HDFC-N' + Math.floor(10000000 + Math.random() * 90000000);
            this.instrumentNumberInput = this.paymentUtrInput;
            this.bankNameInput = 'State Bank of India';
            this.instrumentDateInput = new Date().toISOString().slice(0, 10);
            this.paymentDateInput = new Date().toISOString().slice(0, 10);
            this.isQuickPayModalOpen = true;
        }
    }

    handleCloseQuickPayModal() {
        this.isQuickPayModalOpen = false;
    }

    handlePayInstallmentChange(event) {
        this.selectedPayInstallmentId = event.detail.value;
        const inst = this.rawInstallments.find(i => i.id === this.selectedPayInstallmentId);
        if (inst) {
            this.paymentAmountInput = inst.outstandingAmount;
        }
    }

    handlePaymentAmountChange(event) { this.paymentAmountInput = event.detail.value; }
    handlePayModeChange(event) { this.paymentModeInput = event.detail.value; }
    handlePaymentUtrChange(event) { 
        this.paymentUtrInput = event.detail.value;
        if (!this.instrumentNumberInput) {
            this.instrumentNumberInput = event.detail.value;
        }
    }
    handlePaymentDateChange(event) { this.paymentDateInput = event.detail.value; }
    handleInstrumentDateChange(event) { this.instrumentDateInput = event.detail.value; }
    handleInstrumentNumberChange(event) { this.instrumentNumberInput = event.detail.value; }
    handleBankNameChange(event) { this.bankNameInput = event.detail.value; }

    async handleSubmitPaymentReceipt() {
        if (!this.selectedPayInstallmentId) {
            this.showToast('Validation Error', 'Please select an installment to credit.', 'warning');
            return;
        }
        if (!this.paymentAmountInput || this.paymentAmountInput <= 0) {
            this.showToast('Validation Error', 'Please enter a valid payment amount.', 'warning');
            return;
        }
        if (!this.paymentUtrInput) {
            this.showToast('Validation Error', 'Please enter Bank UTR / Cheque reference.', 'warning');
            return;
        }

        this.isSubmitting = true;
        try {
            const res = await logDetailedReceipt({
                bookingId: this.selectedBookingId || this.recordId,
                installmentId: this.selectedPayInstallmentId,
                amount: Number(this.paymentAmountInput),
                paymentMode: this.paymentModeInput,
                utrNumber: this.paymentUtrInput,
                receiptDate: this.paymentDateInput,
                instrumentDate: this.instrumentDateInput,
                instrumentNumber: this.instrumentNumberInput || this.paymentUtrInput,
                bankName: this.bankNameInput
            });

            this.showToast('Payment Recorded!', res.message, 'success');
            this.isQuickPayModalOpen = false;
            await this.loadAllLedgerData();
            try {
                const notifyList = [{ recordId: this.recordId }];
                if (this.selectedBookingId && this.selectedBookingId !== this.recordId) {
                    notifyList.push({ recordId: this.selectedBookingId });
                }
                await notifyRecordUpdateAvailable(notifyList);
            } catch (e) {
                console.warn(e);
            }
        } catch (error) {
            this.showToast('Error Recording Payment', error.body?.message || error.message, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // Formatters
    formatPrice(val) {
        if (!val && val !== 0) return '0.00';
        return Number(val).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
