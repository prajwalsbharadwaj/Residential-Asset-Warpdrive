import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import getQuoteCommercials from '@salesforce/apex/UnitSelectionQuoteController.getQuoteCommercials';
import updateQuoteCommercials from '@salesforce/apex/UnitSelectionQuoteController.updateQuoteCommercials';
import agreeQuotation from '@salesforce/apex/UnitSelectionQuoteController.agreeQuotation';

export default class QuoteCommercialEditor extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isLoading = true;
    @track isSaving = false;
    @track isSubmitting = false;

    // Quote & Opp Details
    @track quoteName = 'Quotation';
    @track quoteStatus = 'Presented';
    @track oppId = '';
    @track oppName = '';
    @track oppStage = '';
    @track customerName = 'Valued Customer';

    // Strictly Locked Unit Specs
    @track unitId = '';
    @track unitName = 'Unit';
    @track configuration = '2 BHK';
    @track towerName = 'Tower';
    @track projectName = 'Project';
    @track floorNumber = 5;
    @track viewFacing = 'East Facing';
    @track sbaSqFt = 1050;
    @track carpetAreaSqFt = 798;
    @track baseRatePerSqFt = 4650;
    @track floorRiseRate = 0;
    @track effectiveRate = 4650;

    // Restricted Commercial Negotiation Inputs
    @track discountInput = 0;
    @track parkingSlotsInput = 1;
    @track plcRateInput = 100;
    @track notesInput = '';

    parkingOptions = [
        { label: 'No Parking Slot (₹0)', value: 0 },
        { label: '1 Covered Basement Bay (₹2,75,000)', value: 1 },
        { label: '2 Covered Basement Bays (₹5,50,000)', value: 2 }
    ];

    plcOptions = [
        { label: 'Standard Facing (₹0 / sq.ft.)', value: 0 },
        { label: 'East Facing - Park View (₹100 / sq.ft.)', value: 100 },
        { label: 'Corner Unit - Dual Balcony (₹150 / sq.ft.)', value: 150 },
        { label: 'Skyline & Olympic Pool View (₹200 / sq.ft.)', value: 200 }
    ];

    connectedCallback() {
        this.loadQuoteDetails();
    }

    async loadQuoteDetails() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            const data = await getQuoteCommercials({ quoteId: this.recordId });
            if (data) {
                this.quoteName = data.quoteName;
                this.quoteStatus = data.quoteStatus;
                this.oppId = data.oppId;
                this.oppName = data.oppName;
                this.oppStage = data.oppStage;
                this.customerName = data.customerName;

                // Locked unit specs
                this.unitId = data.unitId;
                this.unitName = data.unitName;
                this.configuration = data.configuration;
                this.towerName = data.towerName;
                this.projectName = data.projectName;
                this.floorNumber = data.floorNumber;
                this.viewFacing = data.viewFacing;
                this.sbaSqFt = data.sbaSqFt;
                this.carpetAreaSqFt = data.carpetAreaSqFt;
                this.baseRatePerSqFt = data.baseRatePerSqFt;
                this.floorRiseRate = data.floorRiseRate;
                this.effectiveRate = data.effectiveRate;

                // Editable items
                this.discountInput = data.discountPerSqFt || 0;
                this.parkingSlotsInput = data.parkingSlots != null ? data.parkingSlots : 1;
                this.plcRateInput = data.plcRate != null ? data.plcRate : 100;
                this.notesInput = data.notes || '';
            }
        } catch (error) {
            console.error('Error loading quote commercials:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Input handlers
    handleDiscountChange(event) {
        this.discountInput = Number(event.detail.value) || 0;
    }

    handleParkingChange(event) {
        this.parkingSlotsInput = Number(event.detail.value);
    }

    handlePlcChange(event) {
        this.plcRateInput = Number(event.detail.value) || 0;
    }

    handleNotesChange(event) {
        this.notesInput = event.detail.value;
    }

    // Save Commercials
    async handleSaveQuoteCommercials() {
        this.isSaving = true;
        try {
            const res = await updateQuoteCommercials({
                quoteId: this.recordId,
                discountPerSqFt: this.discountInput,
                parkingSlots: this.parkingSlotsInput,
                plcRate: this.plcRateInput,
                notes: this.notesInput
            });

            this.showToast('Quotation Saved!', res.message, 'success');
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            if (this.oppId) {
                await notifyRecordUpdateAvailable([{ recordId: this.oppId }]);
            }
            await this.loadQuoteDetails();
        } catch (error) {
            console.error('Error updating quote commercials:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // Customer Agreement Action
    async handleMarkAgreement() {
        if (!this.oppId) return;
        this.isSubmitting = true;
        try {
            const res = await agreeQuotation({
                oppId: this.oppId,
                quoteId: this.recordId
            });

            this.showToast('Quotation Accepted!', res.message, 'success');
            this.quoteStatus = 'Accepted';
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await notifyRecordUpdateAvailable([{ recordId: this.oppId }]);
        } catch (error) {
            console.error('Error agreeing quotation:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // Navigation back to Opportunity
    handleReturnToOpp() {
        if (!this.oppId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.oppId,
                objectApiName: 'Opportunity',
                actionName: 'view'
            }
        });
    }

    // Computed Getters
    get isAccepted() {
        return this.quoteStatus === 'Accepted';
    }

    get statusBadgeClass() {
        return this.isAccepted ? 'status-pill status-accepted' : 'status-pill status-presented';
    }

    get baseCost() {
        return Math.round(Number(this.sbaSqFt) * Number(this.effectiveRate));
    }

    get plcCost() {
        return Math.round(Number(this.sbaSqFt) * Number(this.plcRateInput));
    }

    get parkingCost() {
        return Number(this.parkingSlotsInput) * 275000;
    }

    get discountTotal() {
        return Math.round(Number(this.sbaSqFt) * Number(this.discountInput));
    }

    get netAgreement() {
        const total = (this.baseCost + this.plcCost + this.parkingCost) - this.discountTotal;
        return Math.max(0, total);
    }

    get gstTax() {
        return Math.round(this.netAgreement * 0.05);
    }

    get possessionCharges() {
        return 466800;
    }

    get grandTotal() {
        return this.netAgreement + this.gstTax + this.possessionCharges;
    }

    get baseCostFormatted() { return this.formatPrice(this.baseCost); }
    get plcCostFormatted() { return this.formatPrice(this.plcCost); }
    get parkingCostFormatted() { return this.formatPrice(this.parkingCost); }
    get discountTotalFormatted() { return this.formatPrice(this.discountTotal); }
    get netAgreementFormatted() { return this.formatPrice(this.netAgreement); }
    get gstTaxFormatted() { return this.formatPrice(this.gstTax); }
    get possessionFormatted() { return this.formatPrice(this.possessionCharges); }
    get grandTotalFormatted() { return this.formatPrice(this.grandTotal); }

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
