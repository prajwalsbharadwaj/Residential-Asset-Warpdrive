import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getGREFormData from '@salesforce/apex/SiteVisitController.getGREFormData';
import searchVisitorByPhone from '@salesforce/apex/SiteVisitController.searchVisitorByPhone';
import registerWalkinGuest from '@salesforce/apex/SiteVisitController.registerWalkinGuest';
import getUnitsForProject from '@salesforce/apex/SiteVisitController.getUnitsForProject';

export default class GreWalkinDesk extends NavigationMixin(LightningElement) {
    // Form fields
    @track phone = '';
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track visitorName = '';
    @track projectId = '';
    @track configuration = '3BHK';
    @track unitId = '';
    @track visitedWithFamily = 'No';
    @track notes = '';
    @track closingManagerId = '';
    @track isChannelPartner = false;
    @track channelPartnerId = '';

    // Search & Deduplication state
    @track isSearching = false;
    @track hasSearched = false;
    @track isExistingLead = false;
    @track existingLead = null;
    @track priorVisits = [];
    @track showVisitHistory = false;

    // Dropdown options
    @track projectOptions = [];
    @track salesManagerOptions = [];
    @track channelPartnerOptions = [];
    @track configOptions = [];
    @track unitOptions = [];

    // Session stats & UI state
    @track sessionCheckinCount = 0;
    @track sessionRepeatCount = 0;
    @track currentTime = '';
    @track currentDate = '';
    @track isSubmitting = false;
    @track isSuccess = false;
    @track lastResult = null;

    searchTimeout;
    clockInterval;

    connectedCallback() {
        this.updateClock();
        this.clockInterval = setInterval(() => {
            this.updateClock();
        }, 1000);
        this.loadFormData();
    }

    disconnectedCallback() {
        if (this.clockInterval) {
            clearInterval(this.clockInterval);
        }
    }

    updateClock() {
        const now = new Date();
        this.currentTime = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
        this.currentDate = now.toLocaleDateString([], { weekday: 'long', year: 'numeric', month: 'short', day: 'numeric' });
    }

    async loadFormData() {
        try {
            const data = await getGREFormData();
            if (data) {
                this.projectOptions = (data.projects || []).map(p => ({
                    label: p.Name,
                    value: p.Id
                }));
                if (this.projectOptions.length > 0 && !this.projectId) {
                    this.projectId = this.projectOptions[0].value;
                    this.loadUnitsForProject(this.projectId);
                }

                this.salesManagerOptions = (data.salesManagers || []).map(u => ({
                    label: `${u.name} (${u.subtitle})`,
                    value: u.id
                }));

                this.channelPartnerOptions = (data.channelPartners || []).map(cp => ({
                    label: `${cp.name} - ${cp.subtitle}`,
                    value: cp.id
                }));

                this.configOptions = (data.configurations || ['2BHK', '3BHK', '4BHK', 'Above 4BHK']).map(c => ({
                    label: c,
                    value: c
                }));
            }
        } catch (err) {
            console.error('Error loading form data:', err);
        }
    }

    async loadUnitsForProject(projId) {
        if (!projId) {
            this.unitOptions = [];
            return;
        }
        try {
            const units = await getUnitsForProject({ projectId: projId });
            this.unitOptions = (units || []).map(u => ({
                label: u.displayName || u.name,
                value: u.id
            }));
        } catch (err) {
            console.error('Error fetching units:', err);
            this.unitOptions = [];
        }
    }

    // --- Phone Input & Instant Deduplication ---
    handlePhoneChange(event) {
        this.phone = event.target.value;
        const cleanDigits = (this.phone || '').replace(/\D/g, '');

        if (cleanDigits.length < 10) {
            this.hasSearched = false;
            this.isExistingLead = false;
            this.existingLead = null;
            this.priorVisits = [];
            return;
        }

        // Debounce search by 350ms
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.executePhoneLookup(cleanDigits);
        }, 350);
    }

    async executePhoneLookup(phoneDigits) {
        this.isSearching = true;
        try {
            const result = await searchVisitorByPhone({ rawPhone: phoneDigits });
            this.hasSearched = true;
            this.isSearching = false;

            if (result && result.isExistingLead) {
                this.isExistingLead = true;
                this.existingLead = result;
                this.priorVisits = result.priorVisits || [];

                // Pre-populate known Lead details
                this.firstName = result.firstName || '';
                this.lastName = result.lastName || '';
                this.email = result.email || '';
                this.visitorName = result.fullName || `${result.firstName || ''} ${result.lastName || ''}`.trim();

                if (result.projectId) {
                    this.projectId = result.projectId;
                    this.loadUnitsForProject(result.projectId);
                }
                if (result.configuration) {
                    this.configuration = result.configuration;
                }
                if (result.channelPartnerId) {
                    this.isChannelPartner = true;
                    this.channelPartnerId = result.channelPartnerId;
                }
            } else {
                this.isExistingLead = false;
                this.existingLead = null;
                this.priorVisits = [];
                this.visitorName = '';
            }
        } catch (err) {
            this.isSearching = false;
            console.error('Error looking up phone:', err);
        }
    }

    // --- Form Field Handlers ---
    handleFirstName(e) { this.firstName = e.target.value; }
    handleLastName(e) { this.lastName = e.target.value; }
    handleEmail(e) { this.email = e.target.value; }
    handleVisitorName(e) { this.visitorName = e.target.value; }
    
    handleProjectChange(e) {
        this.projectId = e.target.value;
        this.unitId = '';
        this.loadUnitsForProject(this.projectId);
    }

    handleConfigChange(e) { this.configuration = e.target.value; }
    handleUnitChange(e) { this.unitId = e.target.value; }
    
    handleFamilyToggle(e) {
        this.visitedWithFamily = e.target.checked ? 'Yes' : 'No';
    }

    handlePartnerToggle(e) {
        this.isChannelPartner = e.target.checked;
        if (!this.isChannelPartner) {
            this.channelPartnerId = '';
        }
    }

    handlePartnerChange(e) { this.channelPartnerId = e.target.value; }
    handleManagerChange(e) { this.closingManagerId = e.target.value; }
    handleNotesChange(e) { this.notes = e.target.value; }

    toggleHistory() {
        this.showVisitHistory = !this.showVisitHistory;
    }

    // --- Validation & Submission ---
    async handleCheckin() {
        const cleanDigits = (this.phone || '').replace(/\D/g, '');
        if (!cleanDigits || cleanDigits.length < 10) {
            this.showToast('Validation Error', 'Please enter a valid 10-digit mobile number.', 'error');
            return;
        }

        if (!this.isExistingLead && !this.lastName) {
            this.showToast('Validation Error', 'Please enter the guest’s Last Name.', 'error');
            return;
        }

        if (!this.projectId) {
            this.showToast('Validation Error', 'Please select a Project of interest.', 'error');
            return;
        }

        this.isSubmitting = true;

        const payload = {
            leadId: this.isExistingLead && this.existingLead ? this.existingLead.leadId : null,
            firstName: this.firstName,
            lastName: this.lastName,
            mobilePhone: cleanDigits,
            email: this.email,
            visitorName: this.visitorName,
            projectId: this.projectId,
            configuration: this.configuration,
            unitId: this.unitId || null,
            visitedWithFamily: this.visitedWithFamily,
            notes: this.notes,
            closingManagerId: this.closingManagerId || null,
            isChannelPartner: this.isChannelPartner,
            channelPartnerId: this.channelPartnerId || null
        };

        try {
            const res = await registerWalkinGuest({ payload });
            this.isSubmitting = false;

            if (res && res.success) {
                this.isSuccess = true;
                this.lastResult = res;

                this.sessionCheckinCount++;
                if (res.isRepeatVisit) {
                    this.sessionRepeatCount++;
                }

                this.showToast(
                    'Guest Checked In!',
                    res.message,
                    'success'
                );
            } else {
                this.showToast('Check-in Failed', res ? res.message : 'Unknown error', 'error');
            }
        } catch (err) {
            this.isSubmitting = false;
            console.error('Check-in error:', err);
            const msg = (err.body && err.body.message) ? err.body.message : err.message || 'Error creating site visit.';
            this.showToast('Check-in Failed', msg, 'error');
        }
    }

    handleNextGuest() {
        this.resetDesk();
    }

    resetDesk() {
        this.phone = '';
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.visitorName = '';
        this.unitId = '';
        this.visitedWithFamily = 'No';
        this.notes = '';
        this.isChannelPartner = false;
        this.channelPartnerId = '';
        this.hasSearched = false;
        this.isExistingLead = false;
        this.existingLead = null;
        this.priorVisits = [];
        this.showVisitHistory = false;
        this.isSuccess = false;
        this.lastResult = null;
    }

    navigateToLead() {
        if (!this.lastResult || !this.lastResult.leadId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.lastResult.leadId,
                objectApiName: 'Lead',
                actionName: 'view'
            }
        });
    }

    navigateToSiteVisit() {
        if (!this.lastResult || !this.lastResult.siteVisitId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.lastResult.siteVisitId,
                objectApiName: 'Site_Visit__c',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // --- Getters ---
    get isFamilyChecked() {
        return this.visitedWithFamily === 'Yes';
    }

    get priorVisitCount() {
        return this.priorVisits ? this.priorVisits.length : 0;
    }

    get hasPriorVisits() {
        return this.priorVisits && this.priorVisits.length > 0;
    }

    get deskStatusText() {
        if (this.isSearching) return 'Verifying customer in registry...';
        if (this.hasSearched && this.isExistingLead) {
            return `Returning Guest (${this.priorVisitCount} prior visit${this.priorVisitCount === 1 ? '' : 's'})`;
        }
        if (this.hasSearched && !this.isExistingLead) {
            return 'New Guest Registration (First-Time Walk-in)';
        }
        return 'Ready for Next Walk-in Guest';
    }
}
