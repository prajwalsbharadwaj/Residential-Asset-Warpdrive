import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getRequestContext from '@salesforce/apex/RentResaleWorkspaceController.getRequestContext';
import updateOwnerPreferences from '@salesforce/apex/RentResaleWorkspaceController.updateOwnerPreferences';
import markRentalEligible from '@salesforce/apex/RentResaleWorkspaceController.markRentalEligible';
import assignRentalHandling from '@salesforce/apex/RentResaleWorkspaceController.assignRentalHandling';
import addRentalProspect from '@salesforce/apex/RentResaleWorkspaceController.addRentalProspect';
import updateRentalProspectStage from '@salesforce/apex/RentResaleWorkspaceController.updateRentalProspectStage';
import submitRentalOffer from '@salesforce/apex/RentResaleWorkspaceController.submitRentalOffer';
import sendOfferToOwner from '@salesforce/apex/RentResaleWorkspaceController.sendOfferToOwner';
import recordOwnerOfferDecision from '@salesforce/apex/RentResaleWorkspaceController.recordOwnerOfferDecision';
import updateLeaseTerms from '@salesforce/apex/RentResaleWorkspaceController.updateLeaseTerms';
import activateLease from '@salesforce/apex/RentResaleWorkspaceController.activateLease';
import startRenewalStage from '@salesforce/apex/RentResaleWorkspaceController.startRenewalStage';
import recordRenewalDecision from '@salesforce/apex/RentResaleWorkspaceController.recordRenewalDecision';
import assignResaleRequest from '@salesforce/apex/RentResaleWorkspaceController.assignResaleRequest';
import addResaleBuyer from '@salesforce/apex/RentResaleWorkspaceController.addResaleBuyer';
import scheduleResaleSiteVisit from '@salesforce/apex/RentResaleWorkspaceController.scheduleResaleSiteVisit';
import markSiteVisitCompleted from '@salesforce/apex/RentResaleWorkspaceController.markSiteVisitCompleted';
import rescheduleSiteVisit from '@salesforce/apex/RentResaleWorkspaceController.rescheduleSiteVisit';
import logSiteVisitFeedback from '@salesforce/apex/RentResaleWorkspaceController.logSiteVisitFeedback';
import proceedToSiteVisitStage from '@salesforce/apex/RentResaleWorkspaceController.proceedToSiteVisitStage';
import proceedToDealFinalisation from '@salesforce/apex/RentResaleWorkspaceController.proceedToDealFinalisation';
import recordDealFinalisation from '@salesforce/apex/RentResaleWorkspaceController.recordDealFinalisation';
import processDealApproval from '@salesforce/apex/RentResaleWorkspaceController.processDealApproval';
import proceedToKycTokenStage from '@salesforce/apex/RentResaleWorkspaceController.proceedToKycTokenStage';
import recordTokenPayment from '@salesforce/apex/RentResaleWorkspaceController.recordTokenPayment';
import generateTokenReceipt from '@salesforce/apex/RentResaleWorkspaceController.generateTokenReceipt';
import recordAndGenerateTokenReceipt from '@salesforce/apex/RentResaleWorkspaceController.recordAndGenerateTokenReceipt';
import verifyTokenPayment from '@salesforce/apex/RentResaleWorkspaceController.verifyTokenPayment';
import proceedToAllotmentStage from '@salesforce/apex/RentResaleWorkspaceController.proceedToAllotmentStage';
import proceedToFullPaymentStage from '@salesforce/apex/RentResaleWorkspaceController.proceedToFullPaymentStage';
import recordFullPayment from '@salesforce/apex/RentResaleWorkspaceController.recordFullPayment';
import verifyFullPayment from '@salesforce/apex/RentResaleWorkspaceController.verifyFullPayment';
import proceedToTransferDocStage from '@salesforce/apex/RentResaleWorkspaceController.proceedToTransferDocStage';
import generateStampDutyDocument from '@salesforce/apex/RentResaleWorkspaceController.generateStampDutyDocument';
import sendStampDutyForSignature from '@salesforce/apex/RentResaleWorkspaceController.sendStampDutyForSignature';
import completeStampDutySignature from '@salesforce/apex/RentResaleWorkspaceController.completeStampDutySignature';
import recordResaleDealClosure from '@salesforce/apex/RentResaleWorkspaceController.recordResaleDealClosure';
import recordFullPaymentDetails from '@salesforce/apex/RentResaleWorkspaceController.recordFullPaymentDetails';
import proceedToDocumentationStage from '@salesforce/apex/RentResaleWorkspaceController.proceedToDocumentationStage';
import verifyDocument from '@salesforce/apex/RentResaleWorkspaceController.verifyDocument';
import generateDocument from '@salesforce/apex/RentResaleWorkspaceController.generateDocument';
import uploadDocument from '@salesforce/apex/RentResaleWorkspaceController.uploadDocument';
import linkUploadedFile from '@salesforce/apex/RentResaleWorkspaceController.linkUploadedFile';
import shareDocument from '@salesforce/apex/RentResaleWorkspaceController.shareDocument';
import closeResale from '@salesforce/apex/RentResaleWorkspaceController.closeResale';
import rejectResale from '@salesforce/apex/RentResaleWorkspaceController.rejectResale';
import updateResaleListing from '@salesforce/apex/RentResaleWorkspaceController.updateResaleListing';
import moveToResaleStage from '@salesforce/apex/RentResaleWorkspaceController.moveToResaleStage';
import sendActivityEmail from '@salesforce/apex/RentResaleWorkspaceController.sendActivityEmail';
import createActivityTask from '@salesforce/apex/RentResaleWorkspaceController.createActivityTask';
import logActivityCall from '@salesforce/apex/RentResaleWorkspaceController.logActivityCall';
import completeActivityTask from '@salesforce/apex/RentResaleWorkspaceController.completeActivityTask';
import updateRequestOwner from '@salesforce/apex/RentResaleWorkspaceController.updateRequestOwner';

export default class RentResaleWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isLoading = true;
    @track request = null;
    @track recordTypeName = 'Rental';
    @track unitInfo = {};
    @track customerInfo = {};
    @track ownerPreferences = {};
    @track eligibilityChecks = [];
    @track prospects = [];
    @track tenancyHistories = [];
    @track documents = [];
    @track siteVisits = [];
    @track activityTimeline = [];
    @track activeUsers = [];
    @track brokers = [];

    // Resale additions
    @track buyers = [];
    @track financialSummary = {};
    @track assignedPartners = [];
    @track documentFiles = {};
    @track previewDocFile = null;

    // Modals visibility
    @track showEditPreferencesModal = false;
    @track showReviewOfferModal = false;
    @track showAddProspectModal = false;
    @track showScheduleVisitModal = false;
    @track showLogFeedbackModal = false;
    @track showRecordDealModal = false;
    @track showAssignResaleModal = false;
    @track showEditLeaseTermsModal = false;
    @track showAddBuyerModal = false;
    @track showChangeOwnerModal = false;
    @track showRejectResaleModal = false;
    @track showEditListingModal = false;
    @track showVerifyDocModal = false;
    @track showDocPreviewModal = false;
    @track showDocShareModal = false;
    @track showDocUploadModal = false;
    @track showRescheduleVisitModal = false;
    @track showRecordPaymentModal = false;
    @track showApprovalModal = false;
    @track showTokenPaymentModal = false;
    @track showVerifyTokenModal = false;
    @track showFullPaymentModal = false;
    @track showVerifyFullPayModal = false;

    // Active viewing stage (allows viewing prior completed stages)
    @track activeViewingStage = '';

    // Stage 4: Deal Finalisation form
    @track dealBuyerId = '';
    @track dealFinalValue = null;
    @track dealFee = null;
    @track dealTokenAmount = null;
    @track dealPaymentTerms = '10% Token on acceptance, balance within 30 days of approval.';
    @track dealRemarks = '';

    // Stage 5: Approval form
    @track approvalDecision = 'Approved';
    @track approvalRemarksInput = '';

    // Stage 6: Token form
    @track tokenAmountInput = null;
    @track tokenPaymentDate = '';
    @track tokenPaymentMode = 'Bank Transfer (NEFT/RTGS)';
    @track tokenPaymentRef = '';
    @track tokenPaymentProof = '';
    @track tokenPaymentRemarks = '';
    @track tokenVerifyDecision = 'Verified';
    @track tokenVerifyRemarks = '';

    // Stage 8: Full Payment form
    @track fullPaymentAmount = null;
    @track fullPaymentDate = '';
    @track fullPaymentMode = 'Bank Transfer (RTGS)';
    @track fullPaymentRef = '';
    @track fullPayVerifyDecision = 'Verified';
    @track fullPayVerifyRemarks = '';

    // Document Management state
    @track previewDoc = null;
    @track shareDocId = '';
    @track shareDocName = '';
    @track shareRecipientEmail = '';
    @track shareMessage = '';
    @track uploadDocId = '';
    @track uploadDocName = '';
    @track uploadFileName = '';

    // Site visit buyer filter
    @track selectedVisitBuyerFilter = 'ALL';

    // Follow status
    @track isFollowing = false;

    // Active tab in activity panel: 'email' | 'task' | 'call' | 'timeline'
    @track activeActivityTab = 'timeline';

    // Activity inputs
    @track emailTo = '';
    @track emailSubject = '';
    @track emailBody = '';
    @track taskSubject = '';
    @track taskDueDate = '';
    @track taskDescription = '';
    @track callSubject = '';
    @track callComments = '';

    // Modal form fields
    @track activeProspect = {};
    @track prefRent = null;
    @track prefDeposit = null;
    @track prefFurnishing = 'Semi-Furnished';
    @track prefTenant = 'Family';
    @track prefPet = 'Not Allowed';

    @track newProspName = '';
    @track newProspPhone = '';
    @track newProspEmail = '';
    @track newProspRent = null;
    @track newProspDeposit = null;
    @track newProspMoveIn = '';
    @track newProspTenantType = 'Family';

    @track newVisitDate = '';
    @track newVisitTime = '11:00';
    @track newVisitRemarks = '';
    @track newVisitBuyerId = '';
    @track newVisitLocation = '';

    @track activeVisitId = null;
    @track visitRating = ''; // Initial rating must remain Not Rated (never default to Good)
    @track visitFeedback = '';
    @track visitRemarks = '';

    // Reschedule visit fields
    @track rescheduleVisitId = '';
    @track rescheduleVisitDate = '';
    @track rescheduleVisitTime = '11:00 AM';
    @track rescheduleVisitLocation = '';
    @track rescheduleVisitRemarks = '';

    // Record payment details fields
    @track paymentDateInput = '';
    @track paymentRefInput = '';
    @track paymentStatusInput = 'Received';
    @track dealPaymentRef = '';

    @track selectedAgentId = '';
    @track selectedBrokerId = '';
    @track selectedNewOwnerId = '';

    @track leaseRent = null;
    @track leaseDeposit = null;
    @track leaseStartDate = '';
    @track leaseEndDate = '';
    @track leaseLockIn = 11;
    @track leaseEscalation = 5.0;
    @track leaseNotice = 30;
    @track leaseMaintenance = 'Tenant';

    @track buyerName = '';
    @track buyerPhone = '';
    @track buyerEmail = '';
    @track buyerBudget = null;
    @track buyerPreferences = '';
    @track buyerSource = 'Direct';
    @track buyerFinanceNotes = '';
    @track buyerBrokerId = '';

    @track listingAskingPrice = null;
    @track listingStatus = 'Active';
    @track listingDate = '';

    @track activeDocId = '';
    @track activeDocName = '';
    @track docVerifyStatus = 'Verified';
    @track docVerifyRemarks = '';

    @track rejectionReason = 'Owner Changed Mind';
    @track rejectionRemarks = '';

    connectedCallback() {
        this.loadWorkspaceContext();
    }

    async loadWorkspaceContext() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        try {
            this.isLoading = true;
            const res = await getRequestContext({ requestId: this.recordId });
            this.request = res.request;
            this.recordTypeName = res.recordTypeName || (this.request.RecordType ? this.request.RecordType.DeveloperName : 'Rental');
            this.unitInfo = res.unitInfo || {};
            this.customerInfo = res.customerInfo || {};
            this.ownerPreferences = res.ownerPreferences || {};
            this.eligibilityChecks = this.processEligibilityChecks(res.eligibilityChecks || []);
            this.prospects = res.prospects || [];
            this.buyers = this.processBuyers(res.buyers || []);
            this.financialSummary = res.financialSummary || {};
            this.assignedPartners = res.assignedPartners || [];
            this.tenancyHistories = res.tenancyHistories || [];
            this.documents = this.processDocuments(res.documents || []);
            this.documentFiles = res.documentFiles || {};
            this.siteVisits = this.processSiteVisits(res.siteVisits || []);
            this.activityTimeline = this.processTimeline(res.activityTimeline || []);
            this.activeUsers = res.activeUsers || [];
            this.brokers = res.brokers || [];

            // Initialize form fields with request data
            this.prefRent = this.request.Expected_Rent__c;
            this.prefDeposit = this.request.Security_Deposit__c;
            this.prefFurnishing = this.request.Furnishing__c || 'Semi-Furnished';
            this.prefTenant = this.request.Tenant_Preference__c || 'Family';
            this.prefPet = this.request.Pet_Preference__c || 'Not Allowed';

            this.leaseRent = this.request.Monthly_Rent__c || this.request.Expected_Rent__c;
            this.leaseDeposit = this.request.Deposit_Amount__c || this.request.Security_Deposit__c;
            this.leaseStartDate = this.request.Lease_Start_Date__c || '';
            this.leaseEndDate = this.request.Lease_End_Date__c || '';
            this.leaseLockIn = this.request.Lock_In_Period_Months__c || 11;
            this.leaseEscalation = this.request.Escalation_Percent__c || 5.0;
            this.leaseNotice = this.request.Notice_Period_Days__c || 30;
            this.leaseMaintenance = this.request.Maintenance_Responsibility__c || 'Tenant';

            this.listingAskingPrice = this.request.Expected_Resale_Price__c;
            this.listingStatus = this.request.Listing_Status__c || 'Active';
            this.listingDate = this.request.Listing_Date__c || new Date().toISOString().split('T')[0];

            this.emailTo = this.customerInfo.email || '';
            this.newVisitDate = new Date().toISOString().split('T')[0];
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    processEligibilityChecks(checks) {
        return checks.map(c => ({
            ...c,
            iconName: c.isPass ? 'utility:success' : 'utility:warning',
            iconClass: c.isPass ? 'text-success' : 'text-warning',
            statusBadgeClass: c.isPass ? 'slds-badge slds-theme_success' : 'slds-badge slds-badge_lightest'
        }));
    }

    processDocuments(docs) {
        const systemDocTypes = [
            'Possession Letter & Handover Certificate',
            'Resale Agreement',
            'Leave & Licence Agreement (Draft)',
            'Agreement Registration Certificate'
        ];

        return docs.map(d => {
            let statusClass = 'slds-badge ';
            if (d.Status__c === 'Verified') statusClass += 'slds-theme_success';
            else if (d.Status__c === 'Pending') statusClass += 'slds-theme_warning';
            else if (d.Status__c === 'Rejected') statusClass += 'slds-theme_error';
            else statusClass += 'slds-badge_lightest';

            let isVerified = (d.Status__c === 'Verified');
            let isRejected = (d.Status__c === 'Rejected');
            let isPending = (d.Status__c === 'Pending');
            let isRequiredStatus = (d.Status__c === 'Required');
            let isSystemGenerated = systemDocTypes.includes(d.Document_Type__c);
            let sourceType = isSystemGenerated ? 'System Generated' : 'External Upload';
            let sourceBadgeClass = isSystemGenerated ? 'slds-badge slds-theme_info badge-source' : 'slds-badge badge-external badge-source';
            let requirementBadge = d.Is_Required__c ? 'Mandatory' : 'Optional';
            let requirementBadgeClass = d.Is_Required__c ? 'slds-badge badge-mandatory' : 'slds-badge badge-optional';
            let verifiedByName = d.Verified_By__r ? d.Verified_By__r.Name : 'System';
            let verifiedDateFormatted = d.Verified_Date__c ? new Date(d.Verified_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '-';
            let uploadedDateFormatted = d.Uploaded_Date__c ? new Date(d.Uploaded_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '-';

            return {
                ...d,
                statusClass,
                isVerified,
                isRejected,
                isPending,
                isRequiredStatus,
                isSystemGenerated,
                sourceType,
                sourceBadgeClass,
                requirementBadge,
                requirementBadgeClass,
                canGenerate: isSystemGenerated && !isVerified,
                canUpload: !isSystemGenerated && !isVerified,
                canPreview: true,
                canDownload: true,
                canShare: true,
                canVerify: !isVerified,
                verifiedByName,
                verifiedDateFormatted,
                uploadedDateFormatted
            };
        });
    }

    processBuyers(buyers) {
        return buyers.map(b => {
            let budgetFormatted = b.Budget__c ? '₹' + Number(b.Budget__c).toLocaleString('en-IN') : 'Not Specified';
            let createdDateFormatted = b.CreatedDate ? new Date(b.CreatedDate).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '-';
            return {
                ...b,
                budgetFormatted,
                createdDateFormatted
            };
        });
    }

    processSiteVisits(visits) {
        return visits.map(v => {
            let hasRating = !!v.Rating__c;
            let isCompleted = (v.Status__c === 'Completed');
            let isScheduled = !isCompleted;
            let statusBadgeClass = isCompleted ? 'slds-badge slds-theme_success' : 'slds-badge slds-theme_info';
            let ratingBadgeClass = 'slds-badge ';
            if (v.Rating__c === 'Excellent' || v.Rating__c === 'Good') ratingBadgeClass += 'slds-theme_success';
            else if (v.Rating__c === 'Average') ratingBadgeClass += 'slds-theme_warning';
            else if (v.Rating__c === 'Poor') ratingBadgeClass += 'slds-theme_error';
            else ratingBadgeClass += 'slds-badge_lightest';

            let visitDateFormatted = v.Visit_Date__c ? new Date(v.Visit_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '-';
            let visitTime = v.Visit_Time__c || '11:00 AM';
            let location = v.Location__c || 'On-Site / Sales Pavilion';
            let buyerId = v.Buyer__c || '';
            let buyerName = (v.Buyer__r && v.Buyer__r.Prospect_Name__c) ? v.Buyer__r.Prospect_Name__c : 'General Resale Buyer';
            let comments = v.Comments__c || '-';
            let remarks = v.Remarks__c || '-';

            return {
                ...v,
                isCompleted,
                isScheduled,
                statusBadgeClass,
                hasRating,
                ratingBadgeClass,
                visitDateFormatted,
                visitTime,
                location,
                buyerId,
                buyerName,
                comments,
                remarks
            };
        });
    }

    processTimeline(timeline) {
        return timeline.map(item => {
            let iconName = 'standard:task';
            if (item.activityType === 'Email') iconName = 'standard:email';
            else if (item.activityType === 'Call') iconName = 'standard:log_a_call';
            else if (item.activityType === 'Event') iconName = 'standard:event';

            let formattedDate = '';
            if (item.activityDate) {
                const d = new Date(item.activityDate);
                formattedDate = d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
            }

            return {
                ...item,
                iconName,
                formattedDate,
                showCompleteButton: !item.isCompleted && item.activityType === 'Task'
            };
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GETTERS FOR HEADER & CONTEXT
    // ─────────────────────────────────────────────────────────────────────────
    get isRental() {
        return this.recordTypeName === 'Rental';
    }

    get isResale() {
        return this.recordTypeName === 'Resale';
    }

    get headerIcon() {
        return this.isRental ? 'standard:household' : 'standard:sales_cadence';
    }

    get headerTitle() {
        return this.isRental ? 'Rental Management' : 'Resale Assistance';
    }

    get statusBadgeClass() {
        const status = this.request?.Status__c;
        if (status === 'Closed' || status === 'Active Lease') return 'slds-badge slds-theme_success slds-m-left_small';
        if (status === 'Rejected') return 'slds-badge slds-theme_error slds-m-left_small';
        return 'slds-badge slds-theme_info slds-m-left_small';
    }

    get requestDateFormatted() {
        if (!this.request?.Request_Date__c) return '-';
        return new Date(this.request.Request_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get targetDateFormatted() {
        if (!this.request?.Target_Date__c) return '-';
        return new Date(this.request.Target_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get closureDateFormatted() {
        if (!this.request?.Closure_Date__c) return '-';
        return new Date(this.request.Closure_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get closedByName() {
        return this.request?.Closed_By__r?.Name || 'System';
    }

    get assignedAgentName() {
        return this.request?.Assigned_Agent__r?.Name || 'Unassigned';
    }

    get followButtonLabel() {
        return this.isFollowing ? 'Following' : 'Follow';
    }

    get customerInitials() {
        const name = this.customerInfo?.contactName || this.customerInfo?.accountName || 'O';
        return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
    }

    get hasCoOwner() {
        return this.customerInfo?.coOwner && this.customerInfo.coOwner !== 'None';
    }

    get phoneHref() {
        return this.customerInfo?.phone ? `tel:${this.customerInfo.phone}` : '#';
    }

    get emailHref() {
        return this.customerInfo?.email ? `mailto:${this.customerInfo.email}` : '#';
    }

    get ownerCardHeader() {
        return this.isRental ? 'LESSOR / OWNER' : 'SELLER / OWNER';
    }

    get requestHandlingOption() {
        return this.request?.Handling_Option__c || 'In-house Desk';
    }

    get assignedBrokerName() {
        return this.request?.Assigned_Broker__r?.Name || '';
    }

    get availableFromFormatted() {
        if (!this.request?.Available_From__c) return 'Immediate';
        return new Date(this.request.Available_From__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get leasePeriodFormatted() {
        if (!this.request?.Lease_Start_Date__c) return '11 Months Standard';
        const start = new Date(this.request.Lease_Start_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
        const end = this.request.Lease_End_Date__c ? new Date(this.request.Lease_End_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '';
        return `${start} — ${end}`;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RESALE SPECIFIC GETTERS
    // ─────────────────────────────────────────────────────────────────────────
    get buyerOptions() {
        return this.buyers.map(b => ({
            label: `${b.Prospect_Name__c || b.Name} (${b.budgetFormatted || ''})`,
            value: b.Id
        }));
    }

    get hasBuyers() {
        return this.buyers && this.buyers.length > 0;
    }

    get hasAssignedPartners() {
        return this.assignedPartners && this.assignedPartners.length > 0;
    }

    get assignedPartnersDisplay() {
        if (!this.assignedPartners || this.assignedPartners.length === 0) return 'No partners assigned';
        return this.assignedPartners.map(p => p.name).join(', ');
    }

    get originalSaleValueFormatted() {
        const val = this.financialSummary?.originalSaleValue;
        if (!val) return '₹-';
        return '₹' + Number(val).toLocaleString('en-IN');
    }

    get unitCarpetAreaFormatted() {
        if (this.unitInfo && this.unitInfo.carpetArea) {
            return `${Number(this.unitInfo.carpetArea).toLocaleString('en-IN')} sq.ft.`;
        }
        if (this.unitInfo && this.unitInfo.saleableArea) {
            return `${Number(this.unitInfo.saleableArea).toLocaleString('en-IN')} sq.ft.`;
        }
        return '1,450 sq.ft.';
    }

    get registrationDateFormatted() {
        const d = this.financialSummary?.registrationDate;
        if (!d) return 'Pending / Unregistered';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get handoverDateFormatted() {
        const d = this.financialSummary?.handoverDate;
        if (!d) return '-';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get askingResalePriceFormatted() {
        const val = this.request?.Expected_Resale_Price__c;
        if (!val) return 'Not Listed';
        return '₹' + Number(val).toLocaleString('en-IN');
    }

    get listingDateFormatted() {
        const d = this.request?.Listing_Date__c;
        if (!d) return '-';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get listingStatusBadgeClass() {
        const s = this.request?.Listing_Status__c;
        if (s === 'Active') return 'slds-badge slds-theme_success';
        if (s === 'Under Offer') return 'slds-badge slds-theme_warning';
        return 'slds-badge slds-badge_lightest';
    }

    get listingStatusOptions() {
        return [
            { label: 'Active', value: 'Active' },
            { label: 'Under Offer', value: 'Under Offer' },
            { label: 'Off Market', value: 'Off Market' },
            { label: 'Sold', value: 'Sold' }
        ];
    }

    get docDecisionOptions() {
        return [
            { label: 'Approve & Verify', value: 'Verified' },
            { label: 'Reject (Re-upload Required)', value: 'Rejected' },
            { label: 'Mark as Pending', value: 'Pending' }
        ];
    }

    get paymentStatusOptions() {
        return [
            { label: 'Received (Pending Audit)', value: 'Received' },
            { label: 'Verified & Cleared', value: 'Verified' },
            { label: 'Pending / Awaiting Deposit', value: 'Pending' }
        ];
    }

    // Site visit buyer filtering
    get filteredSiteVisits() {
        if (!this.siteVisits || this.siteVisits.length === 0) return [];
        if (this.selectedVisitBuyerFilter === 'ALL') {
            return this.siteVisits;
        }
        return this.siteVisits.filter(v => v.buyerId === this.selectedVisitBuyerFilter);
    }

    get buyerFilterOptions() {
        const isAll = this.selectedVisitBuyerFilter === 'ALL';
        const list = [{
            id: 'ALL',
            name: 'All Registered Buyers',
            count: this.siteVisits.length,
            isSelected: isAll,
            buttonClass: `slds-button slds-button_x-small ${isAll ? 'slds-button_brand' : 'slds-button_neutral'}`
        }];
        for (const b of this.buyers) {
            const count = this.siteVisits.filter(v => v.buyerId === b.Id).length;
            const isSel = this.selectedVisitBuyerFilter === b.Id;
            list.push({
                id: b.Id,
                name: b.Prospect_Name__c || b.Name,
                count: count,
                isSelected: isSel,
                buttonClass: `slds-button slds-button_x-small ${isSel ? 'slds-button_brand' : 'slds-button_neutral'}`
            });
        }
        return list;
    }

    handleSelectBuyerFilter(event) {
        this.selectedVisitBuyerFilter = event.currentTarget.dataset.id;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10-STAGE RESALE SEQUENTIAL PROCESS DEFINITION
    // ─────────────────────────────────────────────────────────────────────────
    get resaleStagesList() {
        return [
            { name: 'Lead Allocation', label: '1. Lead Allocation' },
            { name: 'Property Listing & Buyer Sourcing', label: '2. Listing & Buyers' },
            { name: 'Site Visit', label: '3. Site Visit' },
            { name: 'Deal Finalisation', label: '4. Deal Finalisation' },
            { name: 'Approval', label: '5. Approval' },
            { name: 'KYC & Token', label: '6. KYC & Token' },
            { name: 'Allotment / Welcome', label: '7. Allotment' },
            { name: 'Full Payment & Receipt', label: '8. Full Payment' },
            { name: 'Documentation / Ownership Transfer', label: '9. Ownership Transfer' },
            { name: 'Closed', label: '10. Closed' }
        ];
    }

    get effectiveResaleStage() {
        const actualStage = this.request?.Stage__c || 'Lead Allocation';
        if (this.activeViewingStage) {
            const stagesOrder = [
                'Lead Allocation',
                'Property Listing & Buyer Sourcing',
                'Site Visit',
                'Deal Finalisation',
                'Approval',
                'KYC & Token',
                'Allotment / Welcome',
                'Full Payment & Receipt',
                'Documentation / Ownership Transfer',
                'Closed'
            ];
            const actualIdx = stagesOrder.indexOf(actualStage);
            const viewingIdx = stagesOrder.indexOf(this.activeViewingStage);
            if (viewingIdx !== -1 && viewingIdx <= actualIdx) {
                return this.activeViewingStage;
            }
        }
        return actualStage;
    }

    get isViewingPreviousStage() {
        if (!this.activeViewingStage) return false;
        return this.activeViewingStage !== (this.request?.Stage__c || 'Lead Allocation');
    }

    get isRequestClosed() {
        return this.request?.Stage__c === 'Closed' || this.request?.Status__c === 'Closed';
    }

    get isReadOnlyMode() {
        return this.isViewingPreviousStage || this.isRequestClosed;
    }

    get resaleProcessStages() {
        const currentStage = this.request?.Stage__c || 'Lead Allocation';
        const viewingStage = this.effectiveResaleStage;
        const stages = this.resaleStagesList;

        let currentIndex = stages.findIndex(s => s.name === currentStage);
        if (currentIndex === -1) currentIndex = 0;

        return stages.map((s, index) => {
            const isCompleted = index < currentIndex;
            const isCurrent = (s.name === currentStage);
            const isUpcoming = index > currentIndex;
            const isViewing = (s.name === viewingStage && viewingStage !== currentStage);

            let stepClass = 'sf-path-step ';
            let pillClass = 'process-step-pill ';
            let isClickable = false;
            let isDisabled = false;

            if (isCompleted) {
                stepClass += 'is-completed ';
                pillClass += 'is-completed is-clickable ';
                isClickable = true;
            } else if (isCurrent) {
                stepClass += 'is-current ';
                pillClass += 'is-current ';
            } else {
                stepClass += 'is-upcoming ';
                pillClass += 'is-upcoming ';
                isDisabled = true;
            }

            if (isViewing) {
                stepClass += 'is-viewing-previous ';
                pillClass += 'is-viewing-previous ';
            }

            let tooltip = isCompleted 
                ? `View completed stage: ${s.name} (Read-only)` 
                : (isCurrent ? `Current Active Stage: ${s.name}` : `Upcoming Stage`);

            return {
                ...s,
                stepNumber: index + 1,
                isCompleted,
                isCurrent,
                isUpcoming,
                isViewing,
                isClickable,
                isDisabled,
                stepClass: stepClass.trim(),
                pillClass: pillClass.trim(),
                tooltip,
                showChevron: index < stages.length - 1
            };
        });
    }

    handleSelectStageView(event) {
        const selectedStage = event.currentTarget.dataset.stage;
        const stagesOrder = [
            'Lead Allocation',
            'Property Listing & Buyer Sourcing',
            'Site Visit',
            'Deal Finalisation',
            'Approval',
            'KYC & Token',
            'Allotment / Welcome',
            'Full Payment & Receipt',
            'Documentation / Ownership Transfer',
            'Closed'
        ];
        const actualStage = this.request?.Stage__c || 'Lead Allocation';
        const actualIdx = stagesOrder.indexOf(actualStage);
        const selIdx = stagesOrder.indexOf(selectedStage);

        if (selIdx > actualIdx) {
            this.showToast('Stage Restricted', 'You cannot jump ahead to upcoming stages. Prior stages must be completed first.', 'warning');
            return;
        }
        this.activeViewingStage = selectedStage;
    }

    handleReturnToCurrentStage() {
        this.activeViewingStage = this.request?.Stage__c || 'Lead Allocation';
    }

    // Rental stage path list (for rental requests only)
    get stagesList() {
        const stage = this.request?.Stage__c || '';
        const rentalStages = [
            { name: 'Validation', label: 'Validation' },
            { name: 'Listing', label: 'Listing' },
            { name: 'Tenant & Lease', label: 'Tenant & Lease' },
            { name: 'Active Lease', label: 'Active Lease' },
            { name: 'Renewal', label: 'Renewal' }
        ];

        let currentIndex = rentalStages.findIndex(s => s.name === stage);
        if (currentIndex === -1) currentIndex = 0;

        return rentalStages.map((s, index) => {
            let cssClass = 'slds-path__item ';
            if (index < currentIndex) {
                cssClass += 'slds-is-complete';
            } else if (index === currentIndex) {
                cssClass += 'slds-is-current slds-is-active';
            } else {
                cssClass += 'slds-is-incomplete';
            }
            return { ...s, cssClass };
        });
    }

    // Center Stage Active Condition Getters
    get isRentalValidationStage() {
        return this.isRental && (this.request?.Stage__c === 'Validation' || !this.request?.Stage__c);
    }
    get isRentalListingStage() {
        return this.isRental && this.request?.Stage__c === 'Listing';
    }
    get isRentalTenantLeaseStage() {
        return this.isRental && this.request?.Stage__c === 'Tenant & Lease';
    }
    get isRentalActiveLeaseStage() {
        return this.isRental && this.request?.Stage__c === 'Active Lease';
    }
    get isRentalRenewalStage() {
        return this.isRental && (this.request?.Stage__c === 'Renewal' || this.request?.Stage__c === 'Closed');
    }

    get isResaleLeadAllocationStage() {
        return this.isResale && this.effectiveResaleStage === 'Lead Allocation';
    }
    get isResaleListingSourcingStage() {
        return this.isResale && (this.effectiveResaleStage === 'Property Listing & Buyer Sourcing' || this.effectiveResaleStage === 'Listing & Buyer Sourcing');
    }
    get isResaleSiteVisitStage() {
        return this.isResale && (this.effectiveResaleStage === 'Site Visit' || this.effectiveResaleStage === 'Follow-up');
    }
    get isResaleDealFinalisationStage() {
        return this.isResale && (this.effectiveResaleStage === 'Deal Finalisation' || this.effectiveResaleStage === 'Deal Closure');
    }
    get isResaleApprovalStage() {
        return this.isResale && this.effectiveResaleStage === 'Approval';
    }
    get isResaleKycTokenStage() {
        return this.isResale && (this.effectiveResaleStage === 'KYC & Token' || this.effectiveResaleStage === 'KYC & Full Payment');
    }
    get isResaleAllotmentStage() {
        return this.isResale && this.effectiveResaleStage === 'Allotment / Welcome';
    }
    get isResaleFullPaymentStage() {
        return this.isResale && this.effectiveResaleStage === 'Full Payment & Receipt';
    }
    get isResaleDocumentationTransferStage() {
        return this.isResale && (this.effectiveResaleStage === 'Documentation / Ownership Transfer' || this.effectiveResaleStage === 'Documentation' || this.effectiveResaleStage === 'Documents');
    }
    get isResaleClosedStage() {
        return this.isResale && this.effectiveResaleStage === 'Closed';
    }

    // Stage 3: Site Visits Split
    get upcomingSiteVisits() {
        return this.filteredSiteVisits.filter(v => v.isScheduled);
    }
    get pastSiteVisits() {
        return this.filteredSiteVisits.filter(v => v.isCompleted);
    }
    get hasUpcomingVisits() {
        return this.upcomingSiteVisits && this.upcomingSiteVisits.length > 0;
    }
    get hasPastVisits() {
        return this.pastSiteVisits && this.pastSiteVisits.length > 0;
    }

    // Stage 4/5: Commercial Terms & Approval
    get agreedResalePriceNum() {
        return this.request?.Final_Resale_Value__c || 0;
    }
    get tokenAmountNum() {
        return this.request?.Token_Amount__c || 0;
    }
    get balancePayableNum() {
        return Math.max(0, this.agreedResalePriceNum - this.tokenAmountNum);
    }
    get agreedResalePriceFormatted() {
        const val = this.request?.Final_Resale_Value__c;
        if (!val) return '₹-';
        return '₹' + Number(val).toLocaleString('en-IN');
    }
    get tokenAmountFormatted() {
        const val = this.request?.Token_Amount__c;
        if (!val) return '₹0';
        return '₹' + Number(val).toLocaleString('en-IN');
    }
    get balancePayableFormatted() {
        return '₹' + Number(this.balancePayableNum).toLocaleString('en-IN');
    }
    get serviceFeeFormatted() {
        const fee = this.request?.Service_Fee_Brokerage__c;
        return fee ? '₹' + Number(fee).toLocaleString('en-IN') : '₹0';
    }
    get paymentTermsDisplay() {
        return this.request?.Payment_Terms__c || '10% Token on acceptance, balance within 30 days of approval.';
    }
    get commercialRemarksDisplay() {
        return this.request?.Remarks__c || 'Commercial terms agreed and verified.';
    }
    get approvalStatus() {
        return this.request?.Approval_Status__c || 'Pending Approval';
    }
    get isApprovalPending() {
        return this.approvalStatus === 'Pending Approval';
    }
    get isApprovalApproved() {
        return this.approvalStatus === 'Approved';
    }
    get isApprovalRejected() {
        return this.approvalStatus === 'Rejected';
    }
    get approvalBadgeClass() {
        if (this.isApprovalApproved) return 'slds-badge slds-theme_success';
        if (this.isApprovalRejected) return 'slds-badge slds-theme_error';
        return 'slds-badge slds-theme_warning';
    }
    get approverDisplayName() {
        return this.request?.Approver__r?.Name || 'Designated Approver (Sales Director)';
    }
    get approvalSubmissionDateFormatted() {
        const d = this.request?.Approval_Submission_Date__c;
        if (!d) return '-';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }
    get approvalDateFormatted() {
        const d = this.request?.Approval_Date__c;
        if (!d) return '-';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }
    get approvalRemarksDisplay() {
        return this.request?.Approval_Remarks__c || 'Pending review by Approver.';
    }

    // Stage 6: KYC & Token Payment
    get buyerNameDisplay() {
        return this.request?.Buyer_Name__c || 'Agreed Buyer';
    }

    get buyerKycDocumentsList() {
        if (!this.documents) return [];
        const types = [
            { docType: 'PAN', label: 'PAN Card', categoryHelp: 'Permanent Account Number verification' },
            { docType: 'Identity / Address Proof', label: 'Identity / Address Proof', categoryHelp: 'Aadhaar / Passport / Voter ID' },
            { docType: 'Required KYC Declaration', label: 'Required KYC Declaration', categoryHelp: 'Signed buyer declaration / supporting doc' }
        ];

        return types.map(item => {
            const found = this.documents.find(d => d.Document_Type__c === item.docType);
            const status = found?.Status__c || 'Pending';
            let statusBadgeClass = 'slds-badge slds-theme_warning';
            if (status === 'Verified') statusBadgeClass = 'slds-badge slds-theme_success';
            else if (status === 'Uploaded') statusBadgeClass = 'slds-badge slds-theme_info';
            else if (status === 'Rejected') statusBadgeClass = 'slds-badge slds-theme_error';

            const file = (found && this.documentFiles) ? this.documentFiles[found.Id] : null;
            const hasUploadedFile = !!(found?.Content_Document_Id__c || file);

            const isVerified = status === 'Verified';
            const isUploaded = status === 'Uploaded' || hasUploadedFile;
            const isPending = !isVerified && !isUploaded;

            // 3-state Action Visibility:
            // 1. Initially: Show only UPLOAD
            const showUploadOnly = isPending && !this.isReadOnlyMode;
            // 2. After upload: Show VIEW + VERIFY
            const showViewAndVerify = (isUploaded && !isVerified) || (status === 'Rejected' && hasUploadedFile);
            // 3. After verification: Show VIEW only
            const showViewOnly = isVerified;

            return {
                id: found?.Id,
                docType: item.docType,
                label: item.label,
                categoryHelp: item.categoryHelp,
                status: status,
                statusBadgeClass: statusBadgeClass,
                isVerified: isVerified,
                isUploaded: isUploaded,
                isPending: isPending,
                isRejected: status === 'Rejected',
                showUploadOnly: showUploadOnly,
                showViewAndVerify: showViewAndVerify,
                showViewOnly: showViewOnly,
                canVerify: (isUploaded && !isVerified) && !this.isReadOnlyMode,
                verifiedByName: found?.Verified_By__r?.Name || (found?.Verified_Date__c ? 'System Verified' : '-'),
                verifiedDateFormatted: found?.Verified_Date__c ? new Date(found.Verified_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '-',
                remarks: found?.Remarks__c || ''
            };
        });
    }

    get allBuyerKycDocsVerified() {
        const list = this.buyerKycDocumentsList;
        if (!list || list.length < 3) return false;
        return list.every(item => item.isVerified);
    }

    get buyerKycVerifiedCountDisplay() {
        const list = this.buyerKycDocumentsList;
        if (!list) return '0 of 3';
        const verifiedCount = list.filter(item => item.isVerified).length;
        return `${verifiedCount} of ${list.length}`;
    }

    get tokenPaymentDoc() {
        return this.documents ? this.documents.find(d => d.Document_Type__c === 'Token Payment Receipt') : null;
    }

    get isTokenPaymentRecorded() {
        return !!(this.request?.Token_Amount__c && this.request.Token_Amount__c > 0);
    }

    get isTokenReceiptVerified() {
        const doc = this.tokenPaymentDoc;
        return this.request?.Token_Payment_Status__c === 'Verified' || doc?.Status__c === 'Verified';
    }

    get isTokenReceiptGenerated() {
        const doc = this.tokenPaymentDoc;
        const hasReceiptNumber = !!this.request?.Token_Receipt_Number__c;
        const isDocGen = doc && (doc.Status__c === 'Generated' || doc.Status__c === 'Receipt Generated' || doc.Status__c === 'Verified');
        const reqGen = this.request?.Token_Payment_Status__c === 'Receipt Generated' || this.request?.Token_Payment_Status__c === 'Verified';
        return hasReceiptNumber || isDocGen || reqGen;
    }

    get isTokenReceiptPending() {
        return !this.isTokenReceiptGenerated && !this.isTokenReceiptVerified;
    }

    get isTokenReceiptGeneratedPendingVerify() {
        return this.isTokenReceiptGenerated && !this.isTokenReceiptVerified;
    }

    get isTokenPaymentUnrecorded() {
        return this.isTokenReceiptPending;
    }

    get isTokenPaymentRecordedReceiptPending() {
        return false;
    }

    get tokenReceiptNumber() {
        return this.request?.Token_Receipt_Number__c || (this.isTokenReceiptGenerated ? 'RCP-2026-TOKEN' : '-');
    }

    get tokenReceiptGeneratedDateFormatted() {
        const d = this.tokenPaymentDoc?.Uploaded_Date__c || this.tokenPaymentDoc?.Verified_Date__c || this.request?.Token_Payment_Date__c;
        if (!d) return '-';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get tokenPaymentProofDisplay() {
        return this.request?.Token_Payment_Proof__c || '';
    }

    get tokenPaymentRemarksDisplay() {
        return this.request?.Token_Payment_Remarks__c || '';
    }

    get isTokenReceiptPreview() {
        return this.previewDoc && this.previewDoc.Document_Type__c === 'Token Payment Receipt';
    }

    get tokenPaymentDateFormatted() {
        const d = this.request?.Token_Payment_Date__c;
        if (!d) return '-';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get tokenPaymentStatusBadgeClass() {
        const s = this.request?.Token_Payment_Status__c;
        if (s === 'Verified') return 'slds-badge slds-theme_success';
        if (s === 'Receipt Generated') return 'slds-badge slds-theme_info';
        if (s === 'Rejected') return 'slds-badge slds-theme_error';
        return 'slds-badge slds-theme_warning';
    }

    get canProceedToAllotment() {
        return this.allBuyerKycDocsVerified && this.isTokenReceiptVerified;
    }

    // Stage 7: Allotment / Welcome
    get welcomeLetterDoc() {
        return this.documents.find(d => d.Document_Type__c === 'Welcome Letter' || d.Document_Type__c === 'Welcome / Allocation Letter') || null;
    }
    get allotmentLetterDoc() {
        return this.documents.find(d => d.Document_Type__c === 'Allotment / Confirmation Letter' || d.Document_Type__c === 'Allotment Letter') || null;
    }
    get parkingLetterDoc() {
        return this.documents.find(d => d.Document_Type__c === 'Parking Allocation Letter' || d.Document_Type__c === 'Car Parking Document' || d.Document_Type__c === 'Car Parking Letter') || null;
    }
    get allotmentDocumentsList() {
        if (!this.documents) return [];
        const requiredDocs = [
            { docType: 'Allotment Letter', aliases: ['Allotment Letter', 'Allotment / Confirmation Letter'] },
            { docType: 'Welcome Letter', aliases: ['Welcome Letter', 'Welcome / Allocation Letter'] },
            { docType: 'Car Parking Letter', aliases: ['Car Parking Letter', 'Parking Allocation Letter', 'Car Parking Document'] }
        ];

        return requiredDocs.map(req => {
            const found = this.documents.find(d => req.aliases.includes(d.Document_Type__c)) || {};
            const status = found.Status__c || 'Pending';
            const isGenerated = status === 'Generated' || status === 'Verified';

            return {
                Id: found.Id,
                Document_Type__c: req.docType,
                Status__c: isGenerated ? 'Generated' : 'Pending',
                statusClass: isGenerated ? 'slds-badge slds-theme_success' : 'slds-badge slds-theme_warning',
                isGenerated: isGenerated,
                isPending: !isGenerated,
                Remarks__c: found.Remarks__c || (isGenerated ? 'Generated from Booking template' : 'Ready to generate letter')
            };
        });
    }
    get allAllotmentDocsGenerated() {
        const list = this.allotmentDocumentsList;
        return list && list.length === 3 && list.every(d => d.isGenerated);
    }
    get allAllotmentDocsVerified() {
        return this.allAllotmentDocsGenerated;
    }

    // Document Preview Helper Getters
    get hasPreviewFile() {
        return !!(this.previewDocFile && (this.previewDocFile.downloadUrl || this.previewDocFile.contentDocumentId));
    }
    get hasNoPreviewFile() {
        return !this.hasPreviewFile;
    }
    get isPreviewPdf() {
        return !!(this.previewDocFile && this.previewDocFile.isPdf);
    }
    get isPreviewImage() {
        return !!(this.previewDocFile && this.previewDocFile.isImage);
    }
    get isPreviewOther() {
        return this.hasPreviewFile && !this.isPreviewPdf && !this.isPreviewImage;
    }
    get previewFileDownloadUrl() {
        return this.previewDocFile ? this.previewDocFile.downloadUrl : '';
    }
    get previewFileName() {
        return this.previewDocFile ? this.previewDocFile.fileName : (this.previewDoc?.Document_Type__c || 'Document');
    }

    // Stage 8: Full Payment & Receipt
    get fullPaymentDoc() {
        return this.documents.find(d => d.Document_Type__c === 'Full Payment Receipt' || d.Document_Type__c === 'Payment Receipt') || null;
    }
    get isFullPaymentVerified() {
        return (this.fullPaymentDoc && this.fullPaymentDoc.Status__c === 'Verified') || this.request?.Full_Payment_Status__c === 'Verified';
    }
    get fullPaymentDateFormatted() {
        const d = this.request?.Full_Payment_Date__c || this.request?.Agreement_Closure_Date__c;
        if (!d) return '-';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    }
    get fullPaymentStatusBadgeClass() {
        const s = this.request?.Full_Payment_Status__c;
        if (s === 'Verified') return 'slds-badge slds-theme_success';
        if (s === 'Rejected') return 'slds-badge slds-theme_error';
        return 'slds-badge slds-theme_warning';
    }
    get canProceedToTransferDocs() {
        return this.isFullPaymentVerified;
    }

    // Stage 9: Ownership Transfer / Stamp Duty Document & E-Sign
    get stampDutyDoc() {
        if (!this.documents) return null;
        return this.documents.find(d => 
            d.Document_Type__c === 'Stamp Duty Document' || 
            d.Document_Type__c === 'Stamp Duty & Transfer Document'
        ) || null;
    }

    get stampDutyFile() {
        if (!this.stampDutyDoc || !this.documentFiles) return null;
        return this.documentFiles[this.stampDutyDoc.Id] || null;
    }

    get isStampDutyPendingGeneration() {
        return !this.stampDutyDoc || this.stampDutyDoc.Status__c === 'Pending' || this.stampDutyDoc.Status__c === 'Required';
    }

    get isStampDutyGenerated() {
        return this.stampDutyDoc && this.stampDutyDoc.Status__c === 'Generated';
    }

    get isStampDutyPendingSignature() {
        return this.stampDutyDoc && (
            this.stampDutyDoc.Status__c === 'Pending Signature' || 
            this.stampDutyDoc.Status__c === 'Awaiting Signature'
        );
    }

    get isStampDutySigned() {
        return this.stampDutyDoc && (
            this.stampDutyDoc.Status__c === 'Signed' || 
            this.stampDutyDoc.Status__c === 'Verified'
        );
    }

    get step1Class() {
        if (this.isStampDutyPendingGeneration) return 'esign-flow-step active';
        return 'esign-flow-step completed';
    }

    get step2Class() {
        if (this.isStampDutyPendingGeneration) return 'esign-flow-step';
        if (this.isStampDutyGenerated) return 'esign-flow-step active';
        return 'esign-flow-step completed';
    }

    get step3Class() {
        if (this.isStampDutyPendingGeneration || this.isStampDutyGenerated) return 'esign-flow-step';
        if (this.isStampDutyPendingSignature) return 'esign-flow-step active';
        return 'esign-flow-step completed';
    }

    get step4Class() {
        if (this.isStampDutySigned) return 'esign-flow-step completed active';
        return 'esign-flow-step';
    }

    get stampDutyDocTitle() {
        const unit = this.unitInfo?.name || 'Unit';
        const buyer = this.request?.Buyer_Name__c || 'Buyer';
        return `Stamp Duty & Transfer Deed - ${unit} - ${buyer}`;
    }

    get stampDutyAmountFormatted() {
        const val = this.request?.Final_Resale_Value__c || 15000000;
        const duty = Math.round(val * 0.05);
        return '₹' + Number(duty).toLocaleString('en-IN');
    }

    get stampSurchargeFormatted() {
        const val = this.request?.Final_Resale_Value__c || 15000000;
        const sur = Math.round(val * 0.01);
        return '₹' + Number(sur).toLocaleString('en-IN');
    }

    get stampTotalFormatted() {
        const val = this.request?.Final_Resale_Value__c || 15000000;
        const tot = Math.round(val * 0.06);
        return '₹' + Number(tot).toLocaleString('en-IN');
    }

    get stampDutyEnvelopeId() {
        if (!this.stampDutyDoc?.Remarks__c) return 'ESIGN-ENV-2026-92841';
        const match = this.stampDutyDoc.Remarks__c.match(/ESIGN-ENV-[\w-]+/);
        return match ? match[0] : 'ESIGN-ENV-2026-92841';
    }

    // Metric counts for rental listing stage
    get prospectsEnquiryCount() {
        return this.prospects.filter(p => p.Stage__c === 'Enquiry').length;
    }
    get prospectsVisitCount() {
        return this.prospects.filter(p => p.Stage__c === 'Visit' || p.Stage__c === 'Visited').length;
    }
    get prospectsOfferCount() {
        return this.prospects.filter(p => p.Stage__c === 'Offer' || p.Offered_Rent__c > 0).length;
    }

    // Rental primary CTA (rental only)
    get primaryActionLabel() {
        const stage = this.request?.Stage__c || '';
        switch (stage) {
            case 'Validation': return 'Mark Rental Eligible →';
            case 'Listing': return '＋ Add Prospect / Offer';
            case 'Tenant & Lease': return 'Activate Lease & Move-in →';
            case 'Active Lease': return 'Initiate Renewal Process →';
            case 'Renewal': return 'Select Renewal Decision →';
            default: return 'Next Stage →';
        }
    }

    get isPrimaryActionDisabled() {
        return false;
    }

    async handlePrimaryActionClick() {
        const stage = this.request?.Stage__c || '';
        switch (stage) {
            case 'Validation':
                await this.handleMarkRentalEligible();
                break;
            case 'Listing':
                this.openAddProspectModal();
                break;
            case 'Tenant & Lease':
                await this.handleActivateLease();
                break;
            case 'Active Lease':
                await this.handleStartRenewalStage();
                break;
            case 'Renewal':
                this.showToast('Renewal Decision', 'Please choose one of the three options below.', 'info');
                break;
        }
    }

    async handleStageClick(event) {
        const targetStage = event.currentTarget.dataset.stage;
        if (!targetStage || targetStage === this.request?.Stage__c) return;

        if (this.isRental) {
            if (targetStage === 'Listing' && this.request.Stage__c === 'Validation') {
                await this.handleMarkRentalEligible();
            } else if (targetStage === 'Renewal' && this.request.Stage__c === 'Active Lease') {
                await this.handleStartRenewalStage();
            } else {
                this.showToast('Stage Navigation', `Transition to ${targetStage} via its primary workflow action.`, 'info');
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RENTAL STAGE ACTIONS
    // ─────────────────────────────────────────────────────────────────────────
    async handleMarkRentalEligible() {
        try {
            this.isLoading = true;
            await markRentalEligible({ requestId: this.recordId });
            this.showToast('Eligible', 'Rental request verified and marked eligible. Stage advanced to Listing.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleActivateLease() {
        try {
            this.isLoading = true;
            await activateLease({ requestId: this.recordId });
            this.showToast('Success', 'Lease activated! Tenancy 1 record created and Unit status updated to Leased.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleStartRenewalStage() {
        try {
            this.isLoading = true;
            await startRenewalStage({ requestId: this.recordId });
            this.showToast('Renewal Initiated', 'Tenancy renewal stage opened. Ready for owner decision.', 'info');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSelectRenewCurrent() {
        try {
            this.isLoading = true;
            await recordRenewalDecision({
                requestId: this.recordId,
                decision: 'Renew Current Tenant',
                remarks: 'Renewed with current tenant under revised terms.',
                newStart: new Date().toISOString().split('T')[0],
                newEnd: null,
                newRent: this.request.Monthly_Rent__c
            });
            this.showToast('Renewed', 'Tenancy renewed with existing tenant.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSelectReRentNew() {
        try {
            this.isLoading = true;
            await recordRenewalDecision({
                requestId: this.recordId,
                decision: 'Re-rent to New Tenant',
                remarks: 'Tenancy 1 completed. Initializing Tenancy 2 listing.',
                newStart: null,
                newEnd: null,
                newRent: null
            });
            this.showToast('Listing Reopened', 'Tenancy 1 archived. Request transitioned back to Listing for Tenancy 2.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSelectStopRenting() {
        try {
            this.isLoading = true;
            await recordRenewalDecision({
                requestId: this.recordId,
                decision: 'Stop Renting',
                remarks: 'Owner requested to stop renting. Unit transitioned to Occupied.',
                newStart: null,
                newEnd: null,
                newRent: null
            });
            this.showToast('Completed', 'Rental request closed. Unit returned to Owner Occupied status.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RESALE STAGE ACTIONS
    // ─────────────────────────────────────────────────────────────────────────
    async handleCloseResale() {
        try {
            this.isLoading = true;
            await closeResale({ requestId: this.recordId });
            this.showToast('Transaction Closed', 'Resale completed! Ownership transferred and Unit status updated.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Validation Error', error?.body?.message || error.message, 'warning');
        } finally {
            this.isLoading = false;
        }
    }

    async handleVerifyDocument(event) {
        const docId = event.currentTarget.dataset.id;
        try {
            this.isLoading = true;
            await verifyDocument({ docId, approved: true, remarks: 'Verified by Post-Sale Advisor' });
            this.showToast('Verified', 'Document successfully verified.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MODAL OPEN / CLOSE HANDLERS
    // ─────────────────────────────────────────────────────────────────────────
    closeModals() {
        this.showEditPreferencesModal = false;
        this.showReviewOfferModal = false;
        this.showAddProspectModal = false;
        this.showScheduleVisitModal = false;
        this.showLogFeedbackModal = false;
        this.showRecordDealModal = false;
        this.showAssignResaleModal = false;
        this.showEditLeaseTermsModal = false;
        this.showAddBuyerModal = false;
        this.showChangeOwnerModal = false;
        this.showRejectResaleModal = false;
        this.showEditListingModal = false;
        this.showVerifyDocModal = false;
        this.showDocPreviewModal = false;
        this.showDocShareModal = false;
        this.showDocUploadModal = false;
        this.showRescheduleVisitModal = false;
        this.showRecordPaymentModal = false;
        this.showApprovalModal = false;
        this.showTokenPaymentModal = false;
        this.showVerifyTokenModal = false;
        this.showFullPaymentModal = false;
        this.showVerifyFullPayModal = false;
    }

    openEditPreferencesModal() {
        this.showEditPreferencesModal = true;
    }

    openReviewOfferModal(event) {
        const prospectId = event.currentTarget.dataset.id;
        this.activeProspect = this.prospects.find(p => p.Id === prospectId) || {};
        this.showReviewOfferModal = true;
    }

    openAddProspectModal() {
        this.showAddProspectModal = true;
    }

    openScheduleVisitModal() {
        this.newVisitDate = new Date().toISOString().split('T')[0];
        this.newVisitBuyerId = (this.selectedVisitBuyerFilter !== 'ALL') ? this.selectedVisitBuyerFilter : (this.buyers.length > 0 ? this.buyers[0].Id : '');
        this.newVisitLocation = 'On-Site / Sales Pavilion';
        this.newVisitRemarks = '';
        this.showScheduleVisitModal = true;
    }

    openScheduleVisitForBuyer(event) {
        const buyerId = event.currentTarget.dataset.id;
        this.newVisitBuyerId = buyerId;
        this.newVisitDate = new Date().toISOString().split('T')[0];
        this.newVisitLocation = 'On-Site / Sales Pavilion';
        this.newVisitRemarks = '';
        this.showScheduleVisitModal = true;
    }

    openLogVisitFeedbackModal(event) {
        this.activeVisitId = event.currentTarget.dataset.id;
        const sv = this.siteVisits.find(v => v.Id === this.activeVisitId);
        this.visitRating = (sv && sv.Rating__c) ? sv.Rating__c : ''; // Never default to Good; remains empty / Not Rated
        this.visitFeedback = (sv && sv.Comments__c && sv.Comments__c !== '-') ? sv.Comments__c : '';
        this.showLogFeedbackModal = true;
    }

    openRescheduleVisitModal(event) {
        this.rescheduleVisitId = event.currentTarget.dataset.id;
        this.rescheduleVisitDate = event.currentTarget.dataset.date || new Date().toISOString().split('T')[0];
        this.rescheduleVisitTime = event.currentTarget.dataset.time || '11:00 AM';
        this.rescheduleVisitLocation = event.currentTarget.dataset.location || 'On-Site / Sales Pavilion';
        this.rescheduleVisitRemarks = event.currentTarget.dataset.remarks || '';
        this.showRescheduleVisitModal = true;
    }

    openRecordDealModal() {
        this.dealFinalValue = this.request?.Expected_Resale_Price__c || 10000000;
        this.dealFee = 100000;
        this.dealTokenAmount = Math.round((this.dealFinalValue || 0) * 0.1);
        this.dealPaymentTerms = '10% Token on acceptance, balance within 30 days of approval.';
        this.dealRemarks = 'Final resale terms agreed with buyer and submitted for approval.';
        if (this.buyers && this.buyers.length > 0) {
            this.dealBuyerId = this.buyers[0].Id;
        }
        this.showRecordDealModal = true;
    }

    openApprovalModal() {
        this.approvalDecision = 'Approved';
        this.approvalRemarksInput = 'Approved by designated authority based on agreed commercial terms.';
        this.showApprovalModal = true;
    }

    openTokenPaymentModal() {
        // Do NOT pre-fill with fake or calculated amount. Use existing entered amount if editing, else empty.
        this.tokenAmountInput = this.request?.Token_Amount__c ? this.request.Token_Amount__c : '';
        this.tokenPaymentDate = this.request?.Token_Payment_Date__c || new Date().toISOString().split('T')[0];
        this.tokenPaymentMode = this.request?.Token_Payment_Mode__c || 'Bank Transfer (NEFT/RTGS)';
        this.tokenPaymentRef = this.request?.Token_Payment_Reference__c || '';
        this.tokenPaymentProof = this.request?.Token_Payment_Proof__c || '';
        this.tokenPaymentRemarks = this.request?.Token_Payment_Remarks__c || '';
        this.showTokenPaymentModal = true;
    }

    openVerifyTokenModal() {
        this.tokenVerifyDecision = 'Verified';
        this.tokenVerifyRemarks = 'Token payment receipt verified against bank statement.';
        this.showVerifyTokenModal = true;
    }

    openFullPaymentModal() {
        this.fullPaymentAmount = this.balancePayableNum || Math.max(0, (this.agreedResalePriceNum - this.tokenAmountNum));
        this.fullPaymentDate = this.request?.Full_Payment_Date__c || new Date().toISOString().split('T')[0];
        this.fullPaymentMode = this.request?.Full_Payment_Mode__c || 'Bank Transfer (RTGS)';
        this.fullPaymentRef = this.request?.Payment_Reference__c || '';
        this.showFullPaymentModal = true;
    }

    openVerifyFullPayModal() {
        this.fullPayVerifyDecision = 'Verified';
        this.fullPayVerifyRemarks = 'Full balance payment verified and cleared in escrow account.';
        this.showVerifyFullPayModal = true;
    }

    openAssignResaleModal() {
        this.selectedAgentId = this.request.Assigned_Agent__c || '';
        this.selectedBrokerId = this.request.Assigned_Broker__c || '';
        this.showAssignResaleModal = true;
    }

    openEditLeaseTermsModal() {
        this.showEditLeaseTermsModal = true;
    }

    openAddBuyerModal() {
        this.showAddBuyerModal = true;
    }

    openChangeOwnerModal() {
        this.selectedNewOwnerId = this.request.OwnerId;
        this.showChangeOwnerModal = true;
    }

    openRejectResaleModal() {
        this.showRejectResaleModal = true;
    }

    openEditListingModal() {
        this.listingAskingPrice = this.request?.Expected_Resale_Price__c;
        this.listingStatus = this.request?.Listing_Status__c || 'Active';
        this.listingDate = this.request?.Listing_Date__c || new Date().toISOString().split('T')[0];
        this.showEditListingModal = true;
    }

    openVerifyDocModal(event) {
        this.activeDocId = event.currentTarget.dataset.id;
        this.activeDocName = event.currentTarget.dataset.name || 'Resale Document';
        const doc = this.documents.find(d => d.Id === this.activeDocId);
        this.docVerifyStatus = doc?.Status__c === 'Verified' ? 'Verified' : 'Verified';
        this.docVerifyRemarks = doc?.Remarks__c || '';
        this.showVerifyDocModal = true;
    }

    // Document Management Actions: Generate, Upload, Preview, Download, Share
    async handleGenerateDoc(event) {
        const docId = event.currentTarget.dataset.id;
        try {
            this.isLoading = true;
            await generateDocument({ docId });
            this.showToast('Generated', 'System document draft generated successfully.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenUploadModal(event) {
        this.uploadDocId = event.currentTarget.dataset.id;
        this.uploadDocName = event.currentTarget.dataset.name || 'Document';
        this.uploadFileName = `${this.uploadDocName.toLowerCase().replace(/[^a-z0-9]/g, '_')}_signed.pdf`;
        this.showDocUploadModal = true;
    }

    handleUploadFileNameChange(e) {
        this.uploadFileName = e.target.value;
    }

    async handleUploadDocSubmit() {
        if (!this.uploadDocId) return;
        try {
            this.isLoading = true;
            await uploadDocument({ docId: this.uploadDocId, fileName: this.uploadFileName || 'document_copy.pdf' });
            this.closeModals();
            this.showToast('Uploaded', `Document ${this.uploadDocName} uploaded successfully and ready for verification.`, 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (!uploadedFiles || uploadedFiles.length === 0) return;
        const uploadedFile = uploadedFiles[0];
        try {
            this.isLoading = true;
            await linkUploadedFile({
                docId: this.uploadDocId,
                contentDocumentId: uploadedFile.documentId,
                fileName: uploadedFile.name
            });
            this.closeModals();
            this.showToast('Uploaded', `File "${uploadedFile.name}" uploaded and linked successfully.`, 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Upload Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handlePreviewDoc(event) {
        const docId = event.currentTarget.dataset.id;
        this.previewDoc = this.documents ? this.documents.find(d => d.Id === docId) : null;
        this.previewDocFile = (this.documentFiles && docId) ? this.documentFiles[docId] : null;
        this.showDocPreviewModal = true;
    }

    handleOpenSalesforceFileViewer() {
        if (this.previewDocFile?.contentDocumentId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    selectedRecordId: this.previewDocFile.contentDocumentId
                }
            });
        } else {
            this.showToast('Notice', 'No Salesforce Content Document is linked.', 'info');
        }
    }

    handleDownloadDoc(event) {
        const docId = event.currentTarget.dataset.id || this.previewDoc?.Id;
        const doc = this.documents ? this.documents.find(d => d.Id === docId) : null;
        const file = (this.documentFiles && docId) ? this.documentFiles[docId] : null;
        if (file && file.downloadUrl) {
            const a = document.createElement('a');
            a.href = file.downloadUrl;
            a.download = file.fileName || `${(doc?.Document_Type__c || 'document').toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
            a.target = '_blank';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            this.showToast('Downloaded', `Download initiated for ${file.fileName || doc?.Document_Type__c || 'file'}.`, 'success');
        } else {
            this.showToast('Notice', 'No uploaded file attached to this document record.', 'info');
        }
    }

    handleOpenShareModal(event) {
        this.shareDocId = event.currentTarget.dataset.id;
        this.shareDocName = event.currentTarget.dataset.name || 'Document';
        this.shareRecipientEmail = this.request?.Buyer_Email__c || this.customerInfo?.email || '';
        this.shareMessage = `Please find the official ${this.shareDocName} attached for your review and compliance for Unit ${this.unitInfo.name}.`;
        this.showDocShareModal = true;
    }

    handleShareRecipientChange(e) {
        this.shareRecipientEmail = e.target.value;
    }

    handleShareMessageChange(e) {
        this.shareMessage = e.target.value;
    }

    async handleShareDocSubmit() {
        if (!this.shareRecipientEmail) {
            this.showToast('Required', 'Please enter a recipient email.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await shareDocument({
                docId: this.shareDocId,
                recipientEmail: this.shareRecipientEmail,
                message: this.shareMessage
            });
            this.closeModals();
            this.showToast('Shared', `Document ${this.shareDocName} shared with ${this.shareRecipientEmail}.`, 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleProceedToSiteVisitStage() {
        try {
            this.isLoading = true;
            await proceedToSiteVisitStage({ requestId: this.recordId });
            this.showToast('Stage Advanced', 'Stage moved to Site Visit.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Validation Error', error?.body?.message || error.message, 'warning');
        } finally {
            this.isLoading = false;
        }
    }

    async handleProceedToDealFinalisation() {
        try {
            this.isLoading = true;
            await proceedToDealFinalisation({ requestId: this.recordId });
            this.showToast('Stage Advanced', 'Stage moved to Deal Finalisation.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Validation Error', error?.body?.message || error.message, 'warning');
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MODAL SAVE LOGIC
    // ─────────────────────────────────────────────────────────────────────────
    async saveOwnerPreferences() {
        try {
            this.isLoading = true;
            await updateOwnerPreferences({
                requestId: this.recordId,
                expectedRent: this.prefRent,
                deposit: this.prefDeposit,
                availDate: this.request.Available_From__c,
                furnishing: this.prefFurnishing,
                tenantPref: this.prefTenant,
                petPref: this.prefPet
            });
            this.closeModals();
            this.showToast('Success', 'Owner preferences updated.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async saveNewProspect() {
        if (!this.newProspName) {
            this.showToast('Required', 'Please enter prospect name.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await addRentalProspect({
                requestId: this.recordId,
                name: this.newProspName,
                phone: this.newProspPhone,
                email: this.newProspEmail,
                source: 'Rental Desk',
                offeredRent: this.newProspRent,
                offeredDeposit: this.newProspDeposit,
                moveInDate: this.newProspMoveIn ? this.newProspMoveIn : null,
                tenantType: this.newProspTenantType
            });
            this.closeModals();
            this.showToast('Success', 'Prospect added successfully.', 'success');
            this.newProspName = '';
            this.newProspPhone = '';
            this.newProspEmail = '';
            this.newProspRent = null;
            this.newProspDeposit = null;
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleAcceptOffer() {
        if (!this.activeProspect?.Id) return;
        try {
            this.isLoading = true;
            await recordOwnerOfferDecision({
                prospectId: this.activeProspect.Id,
                decision: 'Accepted',
                comments: 'Offer accepted by owner. Progressing to Lease configuration.'
            });
            this.closeModals();
            this.showToast('Offer Accepted', 'Tenant selected! Stage advanced to Tenant & Lease.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRejectOffer() {
        if (!this.activeProspect?.Id) return;
        try {
            this.isLoading = true;
            await recordOwnerOfferDecision({
                prospectId: this.activeProspect.Id,
                decision: 'Rejected',
                comments: 'Offer declined by owner.'
            });
            this.closeModals();
            this.showToast('Offer Rejected', 'Offer marked as declined.', 'info');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSendOfferToOwner() {
        if (!this.activeProspect?.Id) return;
        try {
            this.isLoading = true;
            await sendOfferToOwner({ prospectId: this.activeProspect.Id });
            this.closeModals();
            this.showToast('Sent to Owner', 'Offer comparison dispatched to owner for commercial review.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async saveSiteVisit() {
        if (!this.newVisitDate) {
            this.showToast('Required', 'Please pick a visit date.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await scheduleResaleSiteVisit({
                requestId: this.recordId,
                buyerId: this.newVisitBuyerId ? this.newVisitBuyerId : null,
                visitDate: this.newVisitDate,
                visitTimeStr: this.newVisitTime,
                location: this.newVisitLocation,
                instructions: this.newVisitRemarks,
                remarks: this.newVisitRemarks
            });
            this.closeModals();
            this.showToast('Scheduled', 'Site visit scheduled.', 'success');
            this.newVisitRemarks = '';
            this.newVisitBuyerId = '';
            this.newVisitLocation = '';
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async saveVisitFeedback() {
        if (!this.activeVisitId) return;
        try {
            this.isLoading = true;
            await logSiteVisitFeedback({
                visitId: this.activeVisitId,
                feedback: this.visitFeedback + (this.visitRemarks ? ' | Remarks: ' + this.visitRemarks : ''),
                rating: this.visitRating,
                status: 'Completed'
            });
            this.closeModals();
            this.showToast('Feedback Logged', 'Site visit feedback recorded.', 'success');
            this.visitFeedback = '';
            this.visitRemarks = '';
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleMarkSiteVisitCompleted(event) {
        const visitId = event.currentTarget.dataset.id;
        try {
            this.isLoading = true;
            await markSiteVisitCompleted({ visitId });
            this.showToast('Completed', 'Site visit marked as completed.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveRescheduleVisit() {
        if (!this.rescheduleVisitId) return;
        try {
            this.isLoading = true;
            await rescheduleSiteVisit({
                visitId: this.rescheduleVisitId,
                newDate: this.rescheduleVisitDate,
                newTimeStr: this.rescheduleVisitTime,
                newLocation: this.rescheduleVisitLocation,
                newRemarks: this.rescheduleVisitRemarks
            });
            this.showToast('Rescheduled', 'Site visit successfully rescheduled.', 'success');
            this.showRescheduleVisitModal = false;
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Stage 4: Deal Finalisation
    async handleSaveDealFinalisation() {
        if (!this.dealFinalValue || this.dealFinalValue <= 0) {
            this.showToast('Required', 'Please enter a valid agreed resale value.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await recordDealFinalisation({
                requestId: this.recordId,
                selectedBuyerId: this.dealBuyerId ? this.dealBuyerId : null,
                finalValue: this.dealFinalValue,
                fee: this.dealFee,
                tokenAmount: this.dealTokenAmount,
                paymentTerms: this.dealPaymentTerms,
                remarks: this.dealRemarks
            });
            this.closeModals();
            this.showToast('Deal Finalised', 'Commercial terms recorded. Stage advanced to Approval.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Validation Error', error?.body?.message || error.message, 'warning');
        } finally {
            this.isLoading = false;
        }
    }

    async saveResaleDeal() {
        await this.handleSaveDealFinalisation();
    }

    // Stage 5: Approval
    async handleSaveApprovalDecision() {
        try {
            this.isLoading = true;
            await processDealApproval({
                requestId: this.recordId,
                isApproved: this.approvalDecision === 'Approved',
                remarks: this.approvalRemarksInput
            });
            this.closeModals();
            this.showToast('Approval Processed', `Deal decision: ${this.approvalDecision}.`, 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleProceedToKycToken() {
        if (!this.isApprovalApproved) {
            this.showToast('Approval Required', 'Deal must be Approved before proceeding to KYC & Token.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await proceedToKycTokenStage({ requestId: this.recordId });
            this.showToast('Stage Advanced', 'Stage moved to KYC & Token.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Validation Error', error?.body?.message || error.message, 'warning');
        } finally {
            this.isLoading = false;
        }
    }

    // Stage 6: KYC & Token
    openGenerateTokenReceiptModal() {
        this.tokenAmountInput = '';
        this.tokenPaymentDate = new Date().toISOString().split('T')[0];
        this.tokenPaymentMode = 'Bank Transfer (NEFT/RTGS)';
        this.tokenPaymentRef = '';
        this.tokenPaymentRemarks = '';
        this.showTokenPaymentModal = true;
    }

    async handleSaveAndGenerateTokenReceipt() {
        const amt = parseFloat(this.tokenAmountInput);
        if (!amt || isNaN(amt) || amt <= 0) {
            this.showToast('Validation Error', 'Token Amount is required and must be greater than zero.', 'error');
            return;
        }
        if (!this.tokenPaymentDate) {
            this.showToast('Validation Error', 'Payment Date is required.', 'error');
            return;
        }
        if (!this.tokenPaymentMode) {
            this.showToast('Validation Error', 'Payment Mode is required.', 'error');
            return;
        }
        if (!this.tokenPaymentRef || !this.tokenPaymentRef.trim()) {
            this.showToast('Validation Error', 'Payment Reference / UTR is required.', 'error');
            return;
        }

        try {
            this.isLoading = true;
            await recordAndGenerateTokenReceipt({
                requestId: this.recordId,
                tokenAmount: amt,
                tokenDate: this.tokenPaymentDate,
                paymentMode: this.tokenPaymentMode,
                tokenRef: this.tokenPaymentRef.trim(),
                remarks: this.tokenPaymentRemarks ? this.tokenPaymentRemarks.trim() : null
            });
            this.closeModals();
            this.showToast('Receipt Generated', 'Official Token Payment Receipt generated successfully.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveTokenPayment() {
        await this.handleSaveAndGenerateTokenReceipt();
    }

    async handleGenerateTokenReceipt() {
        this.openGenerateTokenReceiptModal();
    }

    async handleVerifyTokenReceipt() {
        try {
            this.isLoading = true;
            await verifyTokenPayment({
                requestId: this.recordId,
                verified: true,
                remarks: 'Token payment receipt verified and cleared.'
            });
            this.showToast('Verified', 'Token Payment Receipt has been verified.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handlePreviewTokenReceipt() {
        const doc = this.tokenPaymentDoc;
        if (!doc) {
            this.showToast('Not Found', 'Token Receipt document not found.', 'warning');
            return;
        }
        this.previewDoc = doc;
        this.previewDocFile = (this.documentFiles && doc.Id) ? this.documentFiles[doc.Id] : null;
        this.showDocPreviewModal = true;
    }

    handleDownloadTokenReceipt() {
        const doc = this.tokenPaymentDoc;
        const file = (doc && this.documentFiles) ? this.documentFiles[doc.Id] : null;
        if (file && file.downloadUrl) {
            const a = document.createElement('a');
            a.href = file.downloadUrl;
            a.download = file.fileName || `Token_Receipt_${this.tokenReceiptNumber}.pdf`;
            a.target = '_blank';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            this.showToast('Downloaded', `Download initiated for Token Receipt ${this.tokenReceiptNumber}.`, 'success');
        } else {
            this.showToast('Notice', 'Token Receipt document file is not yet available for download.', 'info');
        }
    }

    handleShareTokenReceipt() {
        const doc = this.tokenPaymentDoc;
        if (!doc) {
            this.showToast('Not Found', 'Token Receipt document not found.', 'warning');
            return;
        }
        this.shareDocId = doc.Id;
        this.shareDocName = `Token Payment Receipt (${this.tokenReceiptNumber})`;
        this.shareRecipientEmail = this.request?.Buyer_Email__c || this.customerInfo?.email || '';
        this.shareMessage = `Dear ${this.buyerNameDisplay},\n\nPlease find attached your official Token Payment Receipt (${this.tokenReceiptNumber}) for Unit ${this.unitInfo.name}. Token amount received: ${this.tokenAmountFormatted}.`;
        this.showDocShareModal = true;
    }

    async handleSaveVerifyToken() {
        try {
            this.isLoading = true;
            await verifyTokenPayment({
                requestId: this.recordId,
                verified: this.tokenVerifyDecision === 'Verified',
                remarks: this.tokenVerifyRemarks
            });
            this.closeModals();
            this.showToast('Token Verified', `Token payment marked as ${this.tokenVerifyDecision}.`, 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleProceedToAllotment() {
        if (!this.canProceedToAllotment) {
            this.showToast('Prerequisites Incomplete', 'All mandatory New Buyer KYC documents must be verified and the official Token Payment Receipt must be verified.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await proceedToAllotmentStage({ requestId: this.recordId });
            this.showToast('Stage Advanced', 'Stage moved to Allotment / Welcome.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Validation Error', error?.body?.message || error.message, 'warning');
        } finally {
            this.isLoading = false;
        }
    }

    // Stage 7: Allotment / Welcome
    async handleProceedToFullPayment() {
        if (!this.allAllotmentDocsGenerated) {
            this.showToast('Prerequisites Incomplete', 'Allotment Letter, Welcome Letter, and Car Parking Letter must all be Generated.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await proceedToFullPaymentStage({ requestId: this.recordId });
            this.showToast('Stage Advanced', 'Stage moved to Full Payment & Receipt.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Validation Error', error?.body?.message || error.message, 'warning');
        } finally {
            this.isLoading = false;
        }
    }

    // Stage 8: Full Payment & Receipt
    async handleSaveFullPayment() {
        if (!this.fullPaymentAmount || this.fullPaymentAmount <= 0) {
            this.showToast('Required', 'Please enter a valid full payment amount.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await recordFullPayment({
                requestId: this.recordId,
                amount: this.fullPaymentAmount,
                payDate: this.fullPaymentDate ? this.fullPaymentDate : null,
                mode: this.fullPaymentMode,
                ref: this.fullPaymentRef
            });
            this.closeModals();
            this.showToast('Full Payment Recorded', 'Full payment details updated.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveVerifyFullPay() {
        try {
            this.isLoading = true;
            await verifyFullPayment({
                requestId: this.recordId,
                verified: this.fullPayVerifyDecision === 'Verified',
                remarks: this.fullPayVerifyRemarks
            });
            this.closeModals();
            this.showToast('Full Payment Verified', `Payment status marked as ${this.fullPayVerifyDecision}.`, 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleProceedToTransferDocs() {
        if (!this.canProceedToTransferDocs) {
            this.showToast('Prerequisites Incomplete', 'Full Payment must be Received and Verified before proceeding.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await proceedToTransferDocStage({ requestId: this.recordId });
            this.showToast('Stage Advanced', 'Stage moved to Documentation / Ownership Transfer.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Validation Error', error?.body?.message || error.message, 'warning');
        } finally {
            this.isLoading = false;
        }
    }

    // Stage 9: Ownership Transfer & Stage 10: Close
    async handleGenerateStampDutyDoc() {
        try {
            this.isLoading = true;
            await generateStampDutyDocument({ requestId: this.recordId });
            this.showToast('Generated', 'Stamp Duty document auto-populated and generated from Salesforce data.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Generation Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSendStampDutyForSignature() {
        try {
            this.isLoading = true;
            await sendStampDutyForSignature({ requestId: this.recordId });
            this.showToast('Dispatched for E-Sign', `Stamp Duty Document sent for signature to ${this.request?.Buyer_Email__c || 'Buyer'}. Activity timeline updated.`, 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('E-Sign Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleCompleteStampDutySignature() {
        try {
            this.isLoading = true;
            await completeStampDutySignature({ requestId: this.recordId });
            this.showToast('E-Signature Complete', 'Document digitally signed and certified. Activity timeline updated and closure unlocked.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Signature Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleDownloadStampDutyDoc() {
        if (!this.stampDutyDoc) {
            this.showToast('Error', 'No Stamp Duty document record found.', 'error');
            return;
        }
        const file = this.stampDutyFile;
        if (file && file.downloadUrl) {
            const a = document.createElement('a');
            a.href = file.downloadUrl;
            a.download = file.fileName || `Stamp_Duty_Document_${(this.unitInfo?.name || 'unit').replace(/[^a-zA-Z0-9]/g, '_')}.txt`;
            a.target = '_blank';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            this.showToast('Downloaded', `Download initiated for ${file.fileName || 'Stamp Duty Document'}.`, 'success');
        } else {
            this.showToast('Notice', 'File binary is being prepared. Please click Preview or retry in a moment.', 'info');
        }
    }

    handlePreviewStampDutyDoc() {
        if (!this.stampDutyDoc) return;
        const fakeEvt = { currentTarget: { dataset: { id: this.stampDutyDoc.Id } } };
        this.handlePreviewDoc(fakeEvt);
    }

    async handleCloseResaleTransaction() {
        if (!this.isStampDutySigned) {
            this.showToast('Document Not Signed', 'The Stamp Duty Document must be signed via e-sign before closing the resale.', 'warning');
            return;
        }
        await this.handleCloseResale();
    }

    async saveResaleAssignment() {
        if (!this.selectedAgentId) {
            this.showToast('Required', 'Please select an advisor to assign.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await assignResaleRequest({
                requestId: this.recordId,
                teamMemberId: this.selectedAgentId,
                brokerId: this.selectedBrokerId ? this.selectedBrokerId : null
            });
            this.closeModals();
            this.showToast('Assigned', 'Resale lead allocated and moved to Property Listing & Buyer Sourcing stage.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async saveLeaseTerms() {
        try {
            this.isLoading = true;
            await updateLeaseTerms({
                requestId: this.recordId,
                rent: this.leaseRent,
                deposit: this.leaseDeposit,
                startDate: this.leaseStartDate ? this.leaseStartDate : null,
                endDate: this.leaseEndDate ? this.leaseEndDate : null,
                lockInMonths: parseInt(this.leaseLockIn, 10),
                escalation: parseFloat(this.leaseEscalation),
                noticeDays: parseInt(this.leaseNotice, 10),
                maintenance: this.leaseMaintenance
            });
            this.closeModals();
            this.showToast('Success', 'Commercial lease terms configured.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async saveResaleBuyer() {
        if (!this.buyerName) {
            this.showToast('Required', 'Buyer name is required.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await addResaleBuyer({
                requestId: this.recordId,
                name: this.buyerName,
                phone: this.buyerPhone,
                email: this.buyerEmail,
                budget: this.buyerBudget,
                preferences: this.buyerPreferences,
                source: this.buyerSource,
                financeNotes: this.buyerFinanceNotes,
                brokerId: this.buyerBrokerId ? this.buyerBrokerId : null
            });
            this.closeModals();
            this.showToast('Success', 'Buyer profile registered.', 'success');
            this.buyerName = '';
            this.buyerPhone = '';
            this.buyerEmail = '';
            this.buyerBudget = null;
            this.buyerPreferences = '';
            this.buyerFinanceNotes = '';
            this.buyerBrokerId = '';
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async saveListingChanges() {
        try {
            this.isLoading = true;
            await updateResaleListing({
                requestId: this.recordId,
                askingPrice: this.listingAskingPrice,
                listingStatus: this.listingStatus,
                listingDate: this.listingDate ? this.listingDate : null
            });
            this.closeModals();
            this.showToast('Listing Updated', 'Resale property listing updated.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async saveVerifyDocument() {
        if (!this.activeDocId) return;
        try {
            this.isLoading = true;
            const approved = (this.docVerifyStatus === 'Verified');
            await verifyDocument({
                docId: this.activeDocId,
                approved: approved,
                remarks: this.docVerifyRemarks
            });
            this.closeModals();
            this.showToast('Document Updated', 'Verification status recorded.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleProceedToFollowUp() {
        await this.handleProceedToSiteVisit();
    }

    async saveNewRequestOwner() {
        if (!this.selectedNewOwnerId) return;
        try {
            this.isLoading = true;
            await updateRequestOwner({
                requestId: this.recordId,
                newOwnerId: this.selectedNewOwnerId
            });
            this.closeModals();
            this.showToast('Transferred', 'Request owner updated successfully.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async saveRejectResale() {
        if (!this.rejectionRemarks) {
            this.showToast('Required', 'Please explain the reason for rejection.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await rejectResale({
                requestId: this.recordId,
                reason: this.rejectionReason,
                remarks: this.rejectionRemarks
            });
            this.closeModals();
            this.showToast('Cancelled', 'Resale request marked as rejected.', 'info');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // REAL SALESFORCE ACTIVITY PANEL (4 Tabs)
    // ─────────────────────────────────────────────────────────────────────────
    selectTabEmail() { this.activeActivityTab = 'email'; }
    selectTabTask() { this.activeActivityTab = 'task'; }
    selectTabCall() { this.activeActivityTab = 'call'; }
    selectTabTimeline() { this.activeActivityTab = 'timeline'; }

    get isTabEmail() { return this.activeActivityTab === 'email'; }
    get isTabTask() { return this.activeActivityTab === 'task'; }
    get isTabCall() { return this.activeActivityTab === 'call'; }
    get isTabTimeline() { return this.activeActivityTab === 'timeline'; }

    get emailTabClass() {
        return `slds-tabs_default__item ${this.isTabEmail ? 'slds-is-active' : ''}`;
    }
    get taskTabClass() {
        return `slds-tabs_default__item ${this.isTabTask ? 'slds-is-active' : ''}`;
    }
    get callTabClass() {
        return `slds-tabs_default__item ${this.isTabCall ? 'slds-is-active' : ''}`;
    }
    get timelineTabClass() {
        return `slds-tabs_default__item ${this.isTabTimeline ? 'slds-is-active' : ''}`;
    }

    handleEmailToChange(e) { this.emailTo = e.target.value; }
    handleEmailSubjectChange(e) { this.emailSubject = e.target.value; }
    handleEmailBodyChange(e) { this.emailBody = e.target.value; }

    handleTaskSubjectChange(e) { this.taskSubject = e.target.value; }
    handleTaskDueDateChange(e) { this.taskDueDate = e.target.value; }
    handleTaskDescriptionChange(e) { this.taskDescription = e.target.value; }

    handleCallSubjectChange(e) { this.callSubject = e.target.value; }
    handleCallCommentsChange(e) { this.callComments = e.target.value; }

    async handleSendEmail() {
        if (!this.emailTo || !this.emailSubject) {
            this.showToast('Required', 'Recipient and subject are required.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await sendActivityEmail({
                recordId: this.recordId,
                toEmail: this.emailTo,
                subject: this.emailSubject,
                body: this.emailBody
            });
            this.emailSubject = '';
            this.emailBody = '';
            this.showToast('Sent', 'Email logged to activity timeline.', 'success');
            await this.loadWorkspaceContext();
            this.activeActivityTab = 'timeline';
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleCreateTask() {
        if (!this.taskSubject) {
            this.showToast('Required', 'Task subject is required.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await createActivityTask({
                recordId: this.recordId,
                subject: this.taskSubject,
                dueDate: this.taskDueDate ? this.taskDueDate : null,
                priority: 'Normal',
                description: this.taskDescription
            });
            this.taskSubject = '';
            this.taskDescription = '';
            this.showToast('Created', 'Task added to record.', 'success');
            await this.loadWorkspaceContext();
            this.activeActivityTab = 'timeline';
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleLogCall() {
        if (!this.callComments) {
            this.showToast('Required', 'Please write call notes.', 'warning');
            return;
        }
        try {
            this.isLoading = true;
            await logActivityCall({
                recordId: this.recordId,
                subject: this.callSubject || 'Client Call Logged',
                comments: this.callComments
            });
            this.callSubject = '';
            this.callComments = '';
            this.showToast('Logged', 'Call activity logged.', 'success');
            await this.loadWorkspaceContext();
            this.activeActivityTab = 'timeline';
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleCompleteTask(event) {
        const taskId = event.currentTarget.dataset.id;
        try {
            this.isLoading = true;
            await completeActivityTask({ taskId });
            this.showToast('Completed', 'Task marked completed.', 'success');
            await this.loadWorkspaceContext();
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefreshActivities() {
        this.loadWorkspaceContext();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // QUICK ACTIONS & UTILITIES
    // ─────────────────────────────────────────────────────────────────────────
    handleFollow() {
        this.isFollowing = !this.isFollowing;
        this.showToast('Notification', this.isFollowing ? 'You are now following this request.' : 'You stopped following this request.', 'info');
    }

    handlePrintableView() {
        window.print();
    }

    handleQuickCallOwner() {
        this.activeActivityTab = 'call';
        this.callSubject = `Call with Owner ${this.customerInfo.contactName || ''}`;
    }

    handleQuickEmailOwner() {
        this.activeActivityTab = 'email';
        this.emailSubject = `Regarding your ${this.recordTypeName} Request for Unit ${this.unitInfo.name || ''}`;
    }

    handleLogOwnerCheckinCall() {
        this.activeActivityTab = 'call';
        this.callSubject = `Tenancy Check-in with Owner ${this.customerInfo.contactName || ''}`;
    }

    handleRequestDocument() {
        this.activeActivityTab = 'task';
        this.taskSubject = `Follow-up on missing Society NOC / Documents`;
        this.taskDescription = `Contact owner to request required documents for rental letting clearance.`;
    }

    handleDeclineRequest() {
        if (this.isResale) {
            this.openRejectResaleModal();
        } else {
            this.showToast('Decline', 'Rental request decline logged with advisory desk.', 'info');
        }
    }

    // Form inputs change handlers
    handlePrefRentChange(e) { this.prefRent = e.target.value; }
    handlePrefDepositChange(e) { this.prefDeposit = e.target.value; }
    handlePrefFurnishingChange(e) { this.prefFurnishing = e.target.value; }
    handlePrefTenantChange(e) { this.prefTenant = e.target.value; }
    handlePrefPetChange(e) { this.prefPet = e.target.value; }

    handleNewProspNameChange(e) { this.newProspName = e.target.value; }
    handleNewProspPhoneChange(e) { this.newProspPhone = e.target.value; }
    handleNewProspEmailChange(e) { this.newProspEmail = e.target.value; }
    handleNewProspRentChange(e) { this.newProspRent = e.target.value; }
    handleNewProspDepositChange(e) { this.newProspDeposit = e.target.value; }
    handleNewProspMoveInChange(e) { this.newProspMoveIn = e.target.value; }
    handleNewProspTenantTypeChange(e) { this.newProspTenantType = e.target.value; }

    handleNewVisitDateChange(e) { this.newVisitDate = e.target.value; }
    handleNewVisitTimeChange(e) { this.newVisitTime = e.target.value; }
    handleNewVisitRemarksChange(e) { this.newVisitRemarks = e.target.value; }

    handleVisitRatingChange(e) { this.visitRating = e.target.value; }
    handleVisitFeedbackChange(e) { this.visitFeedback = e.target.value; }
    handleVisitRemarksChange(e) { this.visitRemarks = e.target.value; }

    handleRescheduleDateChange(e) { this.rescheduleVisitDate = e.target.value; }
    handleRescheduleTimeChange(e) { this.rescheduleVisitTime = e.target.value; }
    handleRescheduleLocationChange(e) { this.rescheduleVisitLocation = e.target.value; }
    handleRescheduleRemarksChange(e) { this.rescheduleVisitRemarks = e.target.value; }

    handlePaymentDateChange(e) { this.paymentDateInput = e.target.value; }
    handlePaymentRefChange(e) { this.paymentRefInput = e.target.value; }
    handlePaymentStatusChange(e) { this.paymentStatusInput = e.detail ? e.detail.value : e.target.value; }

    handleDealFinalValueChange(e) { this.dealFinalValue = e.target.value; }
    handleDealFeeChange(e) { this.dealFee = e.target.value; }
    handleDealPaymentRefChange(e) { this.dealPaymentRef = e.target.value; }
    handleDealRemarksChange(e) { this.dealRemarks = e.target.value; }

    handleAgentChange(e) { this.selectedAgentId = e.target.value; }
    handleBrokerChange(e) { this.selectedBrokerId = e.target.value; }
    handleNewOwnerChange(e) { this.selectedNewOwnerId = e.target.value; }

    handleLeaseRentChange(e) { this.leaseRent = e.target.value; }
    handleLeaseDepositChange(e) { this.leaseDeposit = e.target.value; }
    handleLeaseStartDateChange(e) { this.leaseStartDate = e.target.value; }
    handleLeaseEndDateChange(e) { this.leaseEndDate = e.target.value; }
    handleLeaseLockInChange(e) { this.leaseLockIn = e.target.value; }
    handleLeaseEscalationChange(e) { this.leaseEscalation = e.target.value; }
    handleLeaseNoticeChange(e) { this.leaseNotice = e.target.value; }
    handleLeaseMaintenanceChange(e) { this.leaseMaintenance = e.target.value; }

    handleBuyerNameChange(e) { this.buyerName = e.target.value; }
    handleBuyerPhoneChange(e) { this.buyerPhone = e.target.value; }
    handleBuyerEmailChange(e) { this.buyerEmail = e.target.value; }
    handleBuyerBudgetChange(e) { this.buyerBudget = e.target.value; }
    handleBuyerSourceChange(e) { this.buyerSource = e.target.value; }
    handleBuyerPreferencesChange(e) { this.buyerPreferences = e.target.value; }
    handleBuyerFinanceNotesChange(e) { this.buyerFinanceNotes = e.target.value; }
    handleBuyerBrokerChange(e) { this.buyerBrokerId = e.detail.value; }

    handleNewVisitBuyerChange(e) { this.newVisitBuyerId = e.detail.value; }
    handleNewVisitLocationChange(e) { this.newVisitLocation = e.target.value; }

    handleDealBuyerChange(e) { this.dealBuyerId = e.detail.value; }

    handleListingAskingPriceChange(e) { this.listingAskingPrice = e.target.value; }
    handleListingStatusChange(e) { this.listingStatus = e.detail.value; }
    handleListingDateChange(e) { this.listingDate = e.target.value; }

    handleDocDecisionChange(e) { this.docVerifyStatus = e.detail.value; }
    handleDocVerifyRemarksChange(e) { this.docVerifyRemarks = e.target.value; }

    handleRejectionReasonChange(e) { this.rejectionReason = e.target.value; }
    handleRejectionRemarksChange(e) { this.rejectionRemarks = e.target.value; }

    handleDealTokenAmountChange(e) { this.dealTokenAmount = e.target.value; }
    handleDealPaymentTermsChange(e) { this.dealPaymentTerms = e.target.value; }
    handleApprovalDecisionChange(e) { this.approvalDecision = e.detail ? e.detail.value : e.target.value; }
    handleApprovalRemarksChange(e) { this.approvalRemarksInput = e.target.value; }

    handleTokenAmountChange(e) { this.tokenAmountInput = e.target.value; }
    handleTokenDateChange(e) { this.tokenPaymentDate = e.target.value; }
    handleTokenModeChange(e) { this.tokenPaymentMode = e.detail ? e.detail.value : e.target.value; }
    handleTokenRefChange(e) { this.tokenPaymentRef = e.target.value; }
    handleTokenProofChange(e) { this.tokenPaymentProof = e.target.value; }
    handleTokenRemarksChange(e) { this.tokenPaymentRemarks = e.target.value; }
    handleTokenVerifyDecisionChange(e) { this.tokenVerifyDecision = e.detail ? e.detail.value : e.target.value; }
    handleTokenVerifyRemarksChange(e) { this.tokenVerifyRemarks = e.target.value; }

    handleFullPayAmountChange(e) { this.fullPaymentAmount = e.target.value; }
    handleFullPayDateChange(e) { this.fullPaymentDate = e.target.value; }
    handleFullPayModeChange(e) { this.fullPaymentMode = e.detail ? e.detail.value : e.target.value; }
    handleFullPayRefChange(e) { this.fullPaymentRef = e.target.value; }
    handleFullPayVerifyDecisionChange(e) { this.fullPayVerifyDecision = e.detail ? e.detail.value : e.target.value; }
    handleFullPayVerifyRemarksChange(e) { this.fullPayVerifyRemarks = e.target.value; }

    get approvalDecisionOptions() {
        return [
            { label: 'Approve Deal (Proceed to KYC & Token)', value: 'Approved' },
            { label: 'Reject Deal (Return to Negotiation)', value: 'Rejected' }
        ];
    }

    get tokenPaymentModeOptions() {
        return [
            { label: 'Bank Transfer (NEFT/RTGS)', value: 'Bank Transfer (NEFT/RTGS)' },
            { label: 'Cheque / Demand Draft', value: 'Cheque' },
            { label: 'Escrow Account Deposit', value: 'Escrow' }
        ];
    }

    get tokenVerifyDecisionOptions() {
        return [
            { label: 'Verified & Cleared', value: 'Verified' },
            { label: 'Rejected (Invalid Reference)', value: 'Rejected' },
            { label: 'Pending Bank Clearance', value: 'Pending' }
        ];
    }

    get fullPayModeOptions() {
        return [
            { label: 'Bank Transfer (RTGS)', value: 'Bank Transfer (RTGS)' },
            { label: 'Wire Transfer / Swift', value: 'Wire Transfer' },
            { label: 'Escrow Release', value: 'Escrow Release' }
        ];
    }

    get fullPayVerifyDecisionOptions() {
        return [
            { label: 'Verified & Cleared', value: 'Verified' },
            { label: 'Rejected', value: 'Rejected' },
            { label: 'Pending Audit', value: 'Pending' }
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PICKLIST / COMBOBOX OPTIONS
    // ─────────────────────────────────────────────────────────────────────────
    get furnishingOptions() {
        return [
            { label: 'Semi-Furnished', value: 'Semi-Furnished' },
            { label: 'Fully Furnished', value: 'Furnished' },
            { label: 'Unfurnished', value: 'Unfurnished' }
        ];
    }

    get tenantOptions() {
        return [
            { label: 'Family', value: 'Family' },
            { label: 'Bachelor', value: 'Bachelor' },
            { label: 'Company Lease', value: 'Company Lease' },
            { label: 'Any', value: 'Any' }
        ];
    }

    get petOptions() {
        return [
            { label: 'Allowed', value: 'Allowed' },
            { label: 'Not Allowed', value: 'Not Allowed' }
        ];
    }

    get ratingOptions() {
        return [
            { label: '-- Select Experience Rating --', value: '' },
            { label: 'Excellent', value: 'Excellent' },
            { label: 'Good', value: 'Good' },
            { label: 'Average', value: 'Average' },
            { label: 'Poor', value: 'Poor' }
        ];
    }

    get maintenanceOptions() {
        return [
            { label: 'Tenant Responsibility', value: 'Tenant' },
            { label: 'Owner Responsibility', value: 'Owner' },
            { label: 'Shared / Fixed', value: 'Shared' }
        ];
    }

    get leadSourceOptions() {
        return [
            { label: 'Direct Walk-in', value: 'Direct' },
            { label: 'In-house Desk', value: 'In-house Desk' },
            { label: 'Channel Partner', value: 'Channel Partner' },
            { label: 'Online Portal', value: 'Online Portal' },
            { label: 'Referral', value: 'Referral' }
        ];
    }

    get rejectionReasonOptions() {
        return [
            { label: 'Owner Changed Mind', value: 'Owner Changed Mind' },
            { label: 'Price Mismatch', value: 'Price Mismatch' },
            { label: 'Buyer Backed Out', value: 'Buyer Backed Out' },
            { label: 'Title / Clearance Issue', value: 'Title / Clearance Issue' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get activeUserOptions() {
        return this.activeUsers.map(u => ({
            label: u.Name + (u.Title ? ` (${u.Title})` : ''),
            value: u.Id
        }));
    }

    get brokerOptions() {
        return this.brokers.map(b => ({
            label: b.Name,
            value: b.Id
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}