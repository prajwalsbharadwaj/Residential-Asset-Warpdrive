import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import saveSalesOfferPDF from '@salesforce/apex/ResaleSalesOfferController.saveSalesOfferPDF';

import SIMULATION_STATUS  from '@salesforce/schema/Quote.Simulation_Status__c';
import PROPOSED_VALUE     from '@salesforce/schema/Quote.Proposed_Resale_Value__c';
import FINAL_RESALE_VALUE from '@salesforce/schema/Quote.Final_Resale_Value__c';
import CHARGEABLE_AREA    from '@salesforce/schema/Quote.Chargeable_Area__c';
import BUYER_NAME         from '@salesforce/schema/Quote.Opportunity.Buyer_Name__c';
import UNIT_NAME          from '@salesforce/schema/Quote.Opportunity.Interested_Unit__r.Name';
import PROJECT_NAME       from '@salesforce/schema/Quote.Opportunity.Interested_Unit__r.Property__r.Name';
import QUOTE_NUMBER       from '@salesforce/schema/Quote.QuoteNumber';
import RESALE_CHARGES     from '@salesforce/schema/Quote.Resale_Charges__c';
import BROKERAGE_FEE      from '@salesforce/schema/Quote.Resale_Brokerage_Fee__c';

const FIELDS = [
    SIMULATION_STATUS, PROPOSED_VALUE, FINAL_RESALE_VALUE, CHARGEABLE_AREA,
    BUYER_NAME, UNIT_NAME, PROJECT_NAME, QUOTE_NUMBER,
    RESALE_CHARGES, BROKERAGE_FEE
];

export default class ResaleSalesOrderForm extends LightningElement {
    @api recordId;

    isLoading = false;
    errorMessage = '';

    paymentType = 'Lump Sum';
    remarks = '';
    dueDate = '';

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    quoteRecord;

    get isWiring() {
        return !this.quoteRecord.data && !this.quoteRecord.error;
    }

    get simulationStatus() {
        return getFieldValue(this.quoteRecord.data, SIMULATION_STATUS);
    }

    get isApproved() {
        return this.simulationStatus === 'Approved';
    }

    get notApprovedMessage() {
        if (this.simulationStatus === 'Submitted') return 'This Quote is pending approval. Generate Sales Offer is available only after the Quote is approved.';
        return 'This Quote has not been approved yet. Please submit it for approval first, then generate the Sales Offer.';
    }

    get proposedValue()   { return getFieldValue(this.quoteRecord.data, PROPOSED_VALUE) || 0; }
    get grandTotal()      { return getFieldValue(this.quoteRecord.data, FINAL_RESALE_VALUE) || 0; }
    get chargeableArea()  { return getFieldValue(this.quoteRecord.data, CHARGEABLE_AREA) || 0; }
    get buyerName()       { return getFieldValue(this.quoteRecord.data, BUYER_NAME) || '–'; }
    get unitName()        { return getFieldValue(this.quoteRecord.data, UNIT_NAME) || '–'; }
    get projectName()     { return getFieldValue(this.quoteRecord.data, PROJECT_NAME) || '–'; }
    get quoteNumber()     { return getFieldValue(this.quoteRecord.data, QUOTE_NUMBER) || '–'; }
    get resaleCharges()   { return getFieldValue(this.quoteRecord.data, RESALE_CHARGES) || 0; }
    get brokerageFee()    { return getFieldValue(this.quoteRecord.data, BROKERAGE_FEE) || 0; }

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
            dueDate:     this.dueDate,
            remarks:     this.remarks
        });

        saveSalesOfferPDF({ quoteId: this.recordId, paymentTermsJson: terms })
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
                this.errorMessage = error?.body?.message || error?.message || 'Failed to generate Sales Offer PDF.';
            });
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}