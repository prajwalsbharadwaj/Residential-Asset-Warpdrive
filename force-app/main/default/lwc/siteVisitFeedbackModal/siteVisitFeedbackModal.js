import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import getSiteVisitDetails from '@salesforce/apex/SiteVisitFeedbackController.getSiteVisitDetails';
import saveSiteVisitFeedback from '@salesforce/apex/SiteVisitFeedbackController.saveSiteVisitFeedback';

export default class SiteVisitFeedbackModal extends LightningElement {
    @api recordId;

    // View state
    @track isLoading = true;
    @track isSaving = false;

    // Customer & Context details
    @track siteVisitName = 'Site Visit';
    @track status = 'In Progress';
    @track customerName = 'Valued Customer';
    @track customerMobile = '';
    @track customerEmail = '';
    @track projectName = 'Nikoo Homes';
    @track buildingName = '';
    @track floorName = '';
    @track unitName = '';
    @track configuration = '';

    // Quick Toggles
    @track visitedWithFamily = 'Yes';
    @track visitedShowFlat = 'Yes';

    // Voice of Customer
    @track overallExperience = 'Superior';
    @track likedProduct = 'Product';
    @track recommendFriends = 'Yes';
    @track customerComments = '';
    @track selectedTags = new Set();

    // Available Sentiment / Objection chips
    rawTags = [
        'Loved Balcony View',
        'Vastu Compliant',
        'High Floor Preferred',
        'Impressed by Clubhouse',
        'Price Discussion Requested',
        'Home Loan Pre-Approved',
        'Comparing Competitor',
        'Ready for Token'
    ];

    // Executive Deal Assessment
    @track rating = 'Hot';
    @track interestPercent = 85;
    @track nextFollowUp = 'Week';
    @track closingManagerId = '';
    @track salesManagerRemarks = '';
    @track closingManagersList = [];

    connectedCallback() {
        if (this.recordId) {
            this.loadDetails();
        }
    }

    @api
    invoke() {
        if (this.recordId) {
            this.loadDetails();
        }
    }

    async loadDetails() {
        this.isLoading = true;
        try {
            const data = await getSiteVisitDetails({ siteVisitId: this.recordId });
            this.siteVisitName = data.siteVisitName || 'Site Visit';
            this.status = data.status || 'In Progress';
            this.customerName = data.customerName || 'Valued Visitor';
            this.customerMobile = data.customerMobile || '';
            this.customerEmail = data.customerEmail || '';
            this.projectName = data.projectName || 'Nikoo Homes';
            this.unitName = data.unitName || '';
            this.buildingName = data.buildingName || '';
            this.floorName = data.floorName || '';
            this.configuration = data.configuration || 'Residence';

            if (data.visitedWithFamily) this.visitedWithFamily = data.visitedWithFamily;
            if (data.visitedShowFlat) this.visitedShowFlat = data.visitedShowFlat;
            if (data.overallExperience) this.overallExperience = data.overallExperience;
            if (data.likedProduct) this.likedProduct = data.likedProduct;
            if (data.recommendFriends) this.recommendFriends = data.recommendFriends;
            if (data.customerComments) this.customerComments = data.customerComments;
            if (data.salesManagerRemarks) this.salesManagerRemarks = data.salesManagerRemarks;
            if (data.rating) this.rating = data.rating;
            if (data.nextFollowUp) this.nextFollowUp = data.nextFollowUp;
            if (data.closingManagerId) this.closingManagerId = data.closingManagerId;

            if (data.interestPercent != null) {
                this.interestPercent = data.interestPercent;
            }

            if (data.closingManagers) {
                this.closingManagersList = data.closingManagers;
            }

            // Restore any selected tags from remarks
            if (data.quickTags) {
                this.rawTags.forEach(t => {
                    if (data.quickTags.includes(t)) {
                        this.selectedTags.add(t);
                    }
                });
            }
        } catch (error) {
            this.showToast('Error', error?.body?.message || 'Could not load site visit details.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Getters for UI display
    get customerInitials() {
        if (!this.customerName) return 'V';
        const parts = this.customerName.trim().split(' ');
        return parts.length > 1
            ? (parts[0][0] + parts[1][0]).toUpperCase()
            : parts[0][0].toUpperCase();
    }

    get unitHierarchyDisplay() {
        const parts = [];
        if (this.buildingName) parts.push(this.buildingName);
        if (this.floorName) parts.push(this.floorName);
        if (this.unitName) parts.push(this.unitName);
        return parts.length > 0 ? parts.join(' • ') : (this.unitName || 'Unit');
    }

    get familyYesClass() {
        return `toggle-pill ${this.visitedWithFamily === 'Yes' ? 'active' : ''}`;
    }
    get familyNoClass() {
        return `toggle-pill ${this.visitedWithFamily === 'No' ? 'active' : ''}`;
    }

    get showFlatYesClass() {
        return `toggle-pill ${this.visitedShowFlat === 'Yes' ? 'active' : ''}`;
    }
    get showFlatNoClass() {
        return `toggle-pill ${this.visitedShowFlat === 'No' ? 'active' : ''}`;
    }

    // Experience ratings
    get expSuperiorClass() { return `choice-pill ${this.overallExperience === 'Superior' ? 'active' : ''}`; }
    get expGoodClass() { return `choice-pill ${this.overallExperience === 'Good' ? 'active' : ''}`; }
    get expAverageClass() { return `choice-pill ${this.overallExperience === 'Average' ? 'active' : ''}`; }
    get expPoorClass() { return `choice-pill ${this.overallExperience === 'Poor' ? 'active' : ''}`; }

    get likedProductClass() { return `choice-pill ${this.likedProduct === 'Product' ? 'active' : ''}`; }
    get likedProjectClass() { return `choice-pill ${this.likedProduct === 'Project' ? 'active' : ''}`; }
    get recommendYesClass() { return `choice-pill ${this.recommendFriends === 'Yes' ? 'active' : ''}`; }

    // Temperature ratings
    get ratingColdClass() { return `temp-card cold ${this.rating === 'Cold' ? 'active' : ''}`; }
    get ratingWarmClass() { return `temp-card warm ${this.rating === 'Warm' ? 'active' : ''}`; }
    get ratingHotClass() { return `temp-card hot ${this.rating === 'Hot' ? 'active' : ''}`; }

    // Follow-up
    get followUpWeekClass() { return `choice-pill ${this.nextFollowUp === 'Week' ? 'active' : ''}`; }
    get followUpFortnightClass() { return `choice-pill ${this.nextFollowUp === 'Fortnight' ? 'active' : ''}`; }

    // Tag options with dynamic selected class
    get tagOptions() {
        return this.rawTags.map(tag => ({
            label: tag,
            cssClass: `tag-chip ${this.selectedTags.has(tag) ? 'selected' : ''}`
        }));
    }

    get closingManagerOptions() {
        return this.closingManagersList.map(mgr => ({
            id: mgr.id,
            name: mgr.name + (mgr.title ? ` (${mgr.title})` : ''),
            selected: mgr.id === this.closingManagerId
        }));
    }

    // =========================================================================
    // DYNAMIC ANIMATED INTEREST SLIDER COMPUTED VALUES
    // =========================================================================
    get interestLevelLabel() {
        if (this.interestPercent <= 25) return 'No Interest';
        if (this.interestPercent <= 50) return 'Low Interest';
        if (this.interestPercent <= 75) return 'Medium Interest';
        return 'High Interest';
    }

    get interestEmoji() {
        if (this.interestPercent <= 25) return '❄️';
        if (this.interestPercent <= 50) return '🌤️';
        if (this.interestPercent <= 75) return '⚡';
        return '🔥';
    }

    get interestBadgeClass() {
        if (this.interestPercent <= 25) return 'interest-badge stage-none';
        if (this.interestPercent <= 50) return 'interest-badge stage-low';
        if (this.interestPercent <= 75) return 'interest-badge stage-medium';
        return 'interest-badge stage-high';
    }

    get sliderThumbStyle() {
        let color = '#ef4444';
        if (this.interestPercent <= 25) color = '#64748b';
        else if (this.interestPercent <= 50) color = '#eab308';
        else if (this.interestPercent <= 75) color = '#f97316';
        return `--slider-thumb-color: ${color};`;
    }

    // Event Handlers
    handleFamilyToggle(e) {
        this.visitedWithFamily = e.currentTarget.dataset.val;
    }

    handleShowFlatToggle(e) {
        this.visitedShowFlat = e.currentTarget.dataset.val;
    }

    handleExperienceSelect(e) {
        this.overallExperience = e.currentTarget.dataset.val;
    }

    handleLikedProductSelect(e) {
        this.likedProduct = e.currentTarget.dataset.val;
    }

    handleRecommendSelect() {
        this.recommendFriends = this.recommendFriends === 'Yes' ? 'No' : 'Yes';
    }

    handleRatingSelect(e) {
        this.rating = e.currentTarget.dataset.val;
    }

    handleFollowUpSelect(e) {
        this.nextFollowUp = e.currentTarget.dataset.val;
    }

    handleClosingManagerChange(e) {
        this.closingManagerId = e.target.value;
    }

    handleCustomerCommentsInput(e) {
        this.customerComments = e.target.value;
    }

    handleSalesManagerRemarksInput(e) {
        this.salesManagerRemarks = e.target.value;
    }

    handleSliderInput(e) {
        this.interestPercent = parseInt(e.target.value, 10);
    }

    handleMilestoneClick(e) {
        this.interestPercent = parseInt(e.currentTarget.dataset.val, 10);
    }

    handleTagClick(e) {
        const tag = e.currentTarget.dataset.label;
        if (this.selectedTags.has(tag)) {
            this.selectedTags.delete(tag);
        } else {
            this.selectedTags.add(tag);
        }
        // Force reactivity for tagOptions getter
        this.selectedTags = new Set(this.selectedTags);
    }

    // Modal Dismissal
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
        try {
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            // Not in quick action context, safe to ignore
        }
    }

    handleBackdropClick(e) {
        if (e.target.classList.contains('modal-overlay')) {
            this.handleClose();
        }
    }

    handleModalClick(e) {
        e.stopPropagation();
    }

    // Save Action
    async handleSaveFeedback() {
        this.isSaving = true;
        try {
            const tagsSummary = Array.from(this.selectedTags).join('; ');
            const payload = {
                siteVisitId: this.recordId,
                rating: this.rating,
                interestPercent: this.interestPercent,
                interestLevel: this.interestLevelLabel.replace(' Interest', ''),
                overallExperience: this.overallExperience,
                likedProduct: this.likedProduct,
                visitedShowFlat: this.visitedShowFlat,
                visitedWithFamily: this.visitedWithFamily,
                recommendFriends: this.recommendFriends,
                nextFollowUp: this.nextFollowUp,
                customerComments: this.customerComments,
                executiveRemarks: tagsSummary,
                salesManagerRemarks: this.salesManagerRemarks,
                quickTags: tagsSummary,
                closingManagerId: this.closingManagerId,
                status: 'Completed'
            };

            const result = await saveSiteVisitFeedback({ req: payload });

            this.showToast('Success', result.message || 'Site visit feedback recorded successfully!', 'success');
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

            this.dispatchEvent(new CustomEvent('saved', { detail: { recordId: this.recordId } }));
            this.handleClose();

        } catch (error) {
            this.showToast('Save Failed', error?.body?.message || 'Could not save feedback.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
