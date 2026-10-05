import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import getOpportunityContext from '@salesforce/apex/UnitSelectionQuoteController.getOpportunityContext';
import getTowersForProject from '@salesforce/apex/UnitSelectionQuoteController.getTowersForProject';
import getUnitsForTower from '@salesforce/apex/UnitSelectionQuoteController.getUnitsForTower';
import saveQuotation from '@salesforce/apex/UnitSelectionQuoteController.saveQuotation';
import agreeQuotation from '@salesforce/apex/UnitSelectionQuoteController.agreeQuotation';

export default class ResidentialCostSheet extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    @track isLoading = true;
    @track isSavingQuote = false;
    @track isAgreeingQuote = false;

    // Context Data
    @track oppContext = {};
    @track towers = [];
    @track selectedTowerId = '';
    @track selectedTower = null;

    @track allUnits = [];
    @track filteredUnits = [];
    @track selectedConfigFilter = 'All';

    // Unit Customization Modal State
    @track isUnitModalOpen = false;
    @track selectedUnit = null;

    // Commercial Customization Inputs (BA Locked rules)
    @track discountInput = 0;
    @track parkingSlotsInput = 1;
    @track plcRateInput = 100;
    @track finishPackageInput = 'Standard Vitrified Finish';
    @track quoteNotesInput = '';

    // Active Quote State
    @track activeQuoteId = null;
    @track activeQuoteName = '';
    @track activeQuoteStatus = '';
    @track activeQuoteTotal = 0;

    configOptions = [
        { label: 'All Configurations', value: 'All' },
        { label: '1 BHK', value: '1 BHK' },
        { label: '2 BHK', value: '2 BHK' },
        { label: '3 BHK', value: '3 BHK' },
        { label: '4 BHK Luxury', value: '4 BHK' }
    ];

    parkingOptions = [
        { label: '1 Covered Basement Bay (₹2,75,000)', value: 1 },
        { label: '2 Covered Basement Bays (₹5,50,000)', value: 2 },
        { label: 'No Parking Slot (₹0)', value: 0 }
    ];

    plcOptions = [
        { label: 'Standard View (₹0 / sq.ft.)', value: 0 },
        { label: 'East Facing - Park View (₹100 / sq.ft.)', value: 100 },
        { label: 'Corner Unit - Dual Balcony (₹150 / sq.ft.)', value: 150 },
        { label: 'Skyline & Olympic Pool View (₹200 / sq.ft.)', value: 200 }
    ];

    finishOptions = [
        { label: 'Standard Vitrified Flooring & Fixtures (Included)', value: 'Standard Vitrified Finish' },
        { label: 'Premium Italian Marble & Smart Automation (+₹1,50,000)', value: 'Premium Italian Marble' }
    ];

    connectedCallback() {
        this.loadInitialContext();
    }

    async loadInitialContext() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            const ctx = await getOpportunityContext({ oppId: this.recordId });
            this.oppContext = ctx || {};
            
            if (ctx && ctx.existingQuoteId) {
                this.activeQuoteId = ctx.existingQuoteId;
                this.activeQuoteName = ctx.existingQuoteName;
                this.activeQuoteStatus = ctx.existingQuoteStatus;
                this.activeQuoteTotal = ctx.existingQuoteTotal;
            }

            if (ctx && ctx.projectId) {
                const towerList = await getTowersForProject({ projectId: ctx.projectId });
                this.towers = towerList || [];
                if (this.towers.length > 0) {
                    this.selectedTowerId = this.towers[0].towerId;
                    this.selectedTower = this.towers[0];
                    await this.loadUnitsForSelectedTower();
                }
            }
        } catch (error) {
            console.error('Error loading opportunity context:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadUnitsForSelectedTower() {
        if (!this.selectedTowerId) return;
        try {
            const units = await getUnitsForTower({ towerId: this.selectedTowerId });
            this.allUnits = units || [];
            this.applyConfigFilter();
        } catch (error) {
            console.error('Error loading units for tower:', error);
        }
    }

    handleTowerChange(event) {
        this.selectedTowerId = event.detail.value;
        this.selectedTower = this.towers.find(t => t.towerId === this.selectedTowerId);
        this.loadUnitsForSelectedTower();
    }

    get towerSelectOptions() {
        return (this.towers || []).map(t => ({
            label: `${t.towerName} (${t.totalFloors} Floors - ${t.availableUnitsCount} Units Available)`,
            value: t.towerId
        }));
    }

    handleConfigFilterChange(event) {
        this.selectedConfigFilter = event.detail.value;
        this.applyConfigFilter();
    }

    applyConfigFilter() {
        if (this.selectedConfigFilter === 'All') {
            this.filteredUnits = this.allUnits;
        } else {
            this.filteredUnits = this.allUnits.filter(u => 
                u.configuration && u.configuration.includes(this.selectedConfigFilter)
            );
        }
    }

    // Modal Handling
    handleSelectUnit(event) {
        const unitId = event.currentTarget.dataset.id;
        const unit = this.allUnits.find(u => u.unitId === unitId);
        if (unit) {
            this.selectedUnit = unit;
            this.discountInput = 0;
            this.parkingSlotsInput = 1;
            this.plcRateInput = 100;
            this.finishPackageInput = 'Standard Vitrified Finish';
            this.quoteNotesInput = '';
            this.isUnitModalOpen = true;
        }
    }

    handleCloseUnitModal() {
        this.isUnitModalOpen = false;
        this.selectedUnit = null;
    }

    // Customization Inputs
    handleDiscountChange(event) { this.discountInput = Number(event.detail.value) || 0; }
    handleParkingChange(event) { this.parkingSlotsInput = Number(event.detail.value); }
    handlePlcChange(event) { this.plcRateInput = Number(event.detail.value) || 0; }
    handleFinishChange(event) { this.finishPackageInput = event.detail.value; }
    handleNotesChange(event) { this.quoteNotesInput = event.detail.value; }

    // Live Calculations in Modal
    get modalCalculations() {
        if (!this.selectedUnit) return {};
        const sba = Number(this.selectedUnit.sbaSqFt) || 0;
        const baseRate = Number(this.selectedUnit.effectiveRate) || 0;
        const discount = Number(this.discountInput) || 0;
        const plc = Number(this.plcRateInput) || 0;
        const parking = Number(this.parkingSlotsInput) * 275000;
        const finish = this.finishPackageInput.includes('Premium') ? 150000 : 0;

        const baseCost = Math.round(sba * baseRate);
        const plcCost = Math.round(sba * plc);
        const discountTotal = Math.round(sba * discount);

        const netAgreement = Math.max(0, (baseCost + plcCost + parking + finish) - discountTotal);
        const gstTax = Math.round(netAgreement * 0.05);
        const possessionCharges = 466800;
        const grandTotal = netAgreement + gstTax + possessionCharges;

        return {
            baseCostFormatted: this.formatPrice(baseCost),
            plcCostFormatted: this.formatPrice(plcCost),
            parkingCostFormatted: this.formatPrice(parking),
            finishCostFormatted: this.formatPrice(finish),
            discountTotalFormatted: this.formatPrice(discountTotal),
            netAgreementFormatted: this.formatPrice(netAgreement),
            gstTaxFormatted: this.formatPrice(gstTax),
            possessionFormatted: this.formatPrice(possessionCharges),
            grandTotalFormatted: this.formatPrice(grandTotal),
            grandTotalRaw: grandTotal,
            netAgreementRaw: netAgreement
        };
    }

    // Save Quote
    async handleConfirmSaveQuote() {
        if (!this.selectedUnit) return;
        this.isSavingQuote = true;
        try {
            const res = await saveQuotation({
                oppId: this.recordId,
                unitId: this.selectedUnit.unitId,
                discountPerSqFt: this.discountInput,
                parkingSlots: this.parkingSlotsInput,
                plcRate: this.plcRateInput,
                finishPackage: this.finishPackageInput,
                notes: this.quoteNotesInput
            });

            this.showToast('Quotation Created!', res.message, 'success');
            this.activeQuoteId = res.quoteId;
            this.activeQuoteName = res.quoteName;
            this.activeQuoteStatus = 'Presented';
            this.activeQuoteTotal = res.grandTotal;

            this.isUnitModalOpen = false;
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await this.loadInitialContext();

        } catch (error) {
            console.error('Error saving quote:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isSavingQuote = false;
        }
    }

    // Customer Agreement Action
    async handleAgreeQuote() {
        if (!this.activeQuoteId) return;
        this.isAgreeingQuote = true;
        try {
            const res = await agreeQuotation({
                oppId: this.recordId,
                quoteId: this.activeQuoteId
            });

            this.showToast('Customer Agreed!', res.message, 'success');
            this.activeQuoteStatus = 'Accepted';
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await this.loadInitialContext();
        } catch (error) {
            console.error('Error accepting quote:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isAgreeingQuote = false;
        }
    }

    // Navigation: Go to Quote
    handleGoToQuote() {
        if (!this.activeQuoteId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.activeQuoteId,
                objectApiName: 'Quote',
                actionName: 'view'
            }
        });
    }

    get hasActiveQuote() {
        return !!this.activeQuoteId;
    }

    get isQuoteAccepted() {
        return this.activeQuoteStatus === 'Accepted';
    }

    get quoteBadgeClass() {
        return this.isQuoteAccepted ? 'badge-accepted' : 'badge-presented';
    }

    get formattedActiveQuoteTotal() {
        return this.formatPrice(this.activeQuoteTotal);
    }

    get isOpportunityClosedWon() {
        return this.oppContext.stageName === 'Closed Won';
    }

    // Milestone schedule table based on active or modal amount
    get milestoneSchedule() {
        const total = this.activeQuoteTotal > 0 ? this.activeQuoteTotal : (this.modalCalculations.grandTotalRaw || 9500000);
        return [
            { id: 1, name: 'On Booking / Token Advance', pct: '10%', amount: this.formatPrice(total * 0.10), status: 'Immediate' },
            { id: 2, name: 'Within 30 Days of Booking (Agreement Signing)', pct: '10%', amount: this.formatPrice(total * 0.10), status: 'On Agreement' },
            { id: 3, name: 'On Completion of Excavation', pct: '5%', amount: this.formatPrice(total * 0.05), status: 'Construction Linked' },
            { id: 4, name: 'On Completion of Foundation & Basement Slab', pct: '10%', amount: this.formatPrice(total * 0.10), status: 'Construction Linked' },
            { id: 5, name: 'On Completion of Ground Floor Slab', pct: '5%', amount: this.formatPrice(total * 0.05), status: 'Construction Linked' },
            { id: 6, name: 'On Completion of 5th Floor Slab', pct: '10%', amount: this.formatPrice(total * 0.10), status: 'Construction Linked' },
            { id: 7, name: 'On Completion of 10th Floor Slab', pct: '10%', amount: this.formatPrice(total * 0.10), status: 'Construction Linked' },
            { id: 8, name: 'On Completion of Terrace Roof Slab', pct: '15%', amount: this.formatPrice(total * 0.15), status: 'Construction Linked' },
            { id: 9, name: 'On Completion of Flooring & External Painting', pct: '15%', amount: this.formatPrice(total * 0.15), status: 'Construction Linked' },
            { id: 10, name: 'On Notice of Possession & Key Handover', pct: '10%', amount: this.formatPrice(total * 0.10), status: 'On Possession' }
        ];
    }

    handlePrint() {
        window.print();
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
