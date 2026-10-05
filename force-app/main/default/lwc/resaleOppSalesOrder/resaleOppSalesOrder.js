import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getApprovedQuoteData from '@salesforce/apex/ResaleSalesOfferController.getApprovedQuoteData';
import saveSalesOrderFromOpportunity from '@salesforce/apex/ResaleSalesOfferController.saveSalesOrderFromOpportunity';

import STAGENAME from '@salesforce/schema/Opportunity.StageName';
import BUYER_NAME from '@salesforce/schema/Opportunity.Buyer_Name__c';
import ACCOUNT_NAME from '@salesforce/schema/Opportunity.Account.Name';
import RESALE_PROJECT from '@salesforce/schema/Opportunity.Resale_Project__c';
import RESALE_TOWER from '@salesforce/schema/Opportunity.Resale_Tower__c';
import RESALE_CONFIG from '@salesforce/schema/Opportunity.Resale_Configuration__c';
import CHARGEABLE_AREA from '@salesforce/schema/Opportunity.Chargeable_Area__c';

const OPP_FIELDS = [STAGENAME, BUYER_NAME, ACCOUNT_NAME, RESALE_PROJECT, RESALE_TOWER, RESALE_CONFIG, CHARGEABLE_AREA];

export default class ResaleOppSalesOrder extends LightningElement {
    @api recordId;

    isLoading = false;
    quoteLoading = true;
    errorMessage = '';
    quoteData = null;

    paymentType = 'Lump Sum';
    dueDate = '';
    remarks = '';

    @wire(getRecord, { recordId: '$recordId', fields: OPP_FIELDS })
    wiredOpp;

    connectedCallback() {
        this.loadQuote();
    }

    loadQuote() {
        this.quoteLoading = true;
        getApprovedQuoteData({ opportunityId: this.recordId })
            .then(data => {
                this.quoteData = data;
                this.quoteLoading = false;
            })
            .catch(err => {
                this.quoteData = null;
                this.quoteLoading = false;
                this.errorMessage = err?.body?.message || 'Could not load the approved Quote.';
            });
    }

    get isWiring() { return !this.wiredOpp.data && !this.wiredOpp.error; }
    get stageName()     { return getFieldValue(this.wiredOpp.data, STAGENAME) || ''; }
    get buyerName()     { return getFieldValue(this.wiredOpp.data, BUYER_NAME) || '–'; }
    get accountName()   { return getFieldValue(this.wiredOpp.data, ACCOUNT_NAME) || '–'; }
    get project()       { return getFieldValue(this.wiredOpp.data, RESALE_PROJECT) || '–'; }
    get tower()         { return getFieldValue(this.wiredOpp.data, RESALE_TOWER) || '–'; }
    get configuration() { return getFieldValue(this.wiredOpp.data, RESALE_CONFIG) || '–'; }
    get chargeableArea(){ return getFieldValue(this.wiredOpp.data, CHARGEABLE_AREA) || 0; }

    get hasApprovedQuote()    { return !!this.quoteData; }
    get quoteNumber()         { return this.quoteData?.quoteNumber || '–'; }
    get originalValue()       { return this.quoteData?.originalBookingValue || 0; }
    get proposedValue()       { return this.quoteData?.proposedResaleValue || 0; }
    get resaleCharges()       { return this.quoteData?.resaleCharges || 0; }
    get brokerageFee()        { return this.quoteData?.brokerageFee || 0; }
    get discount()            { return this.quoteData?.discount || 0; }
    get grandTotal()          { return this.quoteData?.finalResaleValue || 0; }
    get quoteId()             { return this.quoteData?.quoteId; }

    paymentTypeOptions = [
        { label: 'Lump Sum', value: 'Lump Sum' },
        { label: 'Percentage of Total', value: 'Percentage' },
        { label: 'Instalment', value: 'Instalment' },
        { label: 'Flexi Payment', value: 'Flexi Payment' },
        { label: 'Construction Linked', value: 'Construction Linked' }
    ];

    handlePaymentTypeChange(e) { this.paymentType = e.detail.value; }
    handleDueDateChange(e)     { this.dueDate = e.detail.value; }
    handleRemarksChange(e)     { this.remarks = e.detail.value; }

    handleGenerate() {
        if (!this.paymentType) {
            this.errorMessage = 'Please select a Payment Type.';
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';

        const terms = JSON.stringify({
            paymentType: this.paymentType,
            dueDate: this.dueDate,
            remarks: this.remarks
        });

        saveSalesOrderFromOpportunity({ opportunityId: this.recordId, paymentTermsJson: terms })
            .then(contentDocumentId => {
                this.isLoading = false;
                // Close the modal and open the PDF in a new tab for preview + download
                this.dispatchEvent(new CloseActionScreenEvent());
                window.open(
                    '/lightning/r/ContentDocument/' + contentDocumentId + '/view',
                    '_blank',
                    'noopener,noreferrer'
                );
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = error?.body?.message || 'Failed to generate Sales Order.';
            });
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}