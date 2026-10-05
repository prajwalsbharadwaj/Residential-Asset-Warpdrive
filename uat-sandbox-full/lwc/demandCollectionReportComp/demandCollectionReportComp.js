import { LightningElement, track } from 'lwc';
import getPaymentReceipts from '@salesforce/apex/DemandCollectionReportController.getPaymentReceipts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import CUSTOM_DT_STYLE from '@salesforce/resourceUrl/customDTStyle';

export default class DemandCollectionReportComp extends LightningElement {
@track receipts = [];
@track columns = [
    { label: 'Project', fieldName: 'Project', type: 'text', wrapText: true, cellAttributes: { alignment: 'left', class: { fieldName: 'cellClass' } }, initialWidth: 200 },
    { label: 'Subproject', fieldName: 'Subproject', type: 'text', wrapText: true, cellAttributes: { alignment: 'left', class: { fieldName: 'cellClass' } }, initialWidth: 130 },
    { label: 'Customer Name', fieldName: 'CustomerName', type: 'text', wrapText: true, cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 160 },
    { label: 'Unit No', fieldName: 'UnitNo', type: 'text',wrapText: true, cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 200 },
    { label: 'Status', fieldName: 'Status', type: 'text', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 90 },
    { label: 'Base Rate', fieldName: 'BaseRate', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 100 },
    { label: 'SBA', fieldName: 'SBA', type: 'number', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 80 },
    { label: 'Customer Code', fieldName: 'CustCode', type: 'text', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 140 },
    { label: 'Customer Billing Address', fieldName: 'CustomerAddressBillingFormatted', wrapText: true, type: 'text', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 300 },
    { label: 'PAN', fieldName: 'PAN', type: 'text', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 100 },
    { label: 'Demand Created Date', fieldName: 'DemandCreatedDate', type: 'date', cellAttributes: { alignment: 'center', class: { fieldName: 'cellClass' } }, initialWidth: 180 },
    { label: 'Receipt Date', fieldName: 'ReceiptDate', type: 'date', cellAttributes: { alignment: 'center', class: { fieldName: 'cellClass' } }, initialWidth: 140 },
    { label: 'Payment Receipt No.', fieldName: 'PaymentReceiptNumber', type: 'text', cellAttributes: { alignment: 'center', class: { fieldName: 'cellClass' } }, initialWidth: 180 },
    { label: 'Demand Id', fieldName: 'DemandId', type: 'text', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 120 },
    { label: 'Receipt Status', fieldName: 'IsAutoTaxOrReceiptStatus', type: 'text', cellAttributes: { alignment: 'center', class: { fieldName: 'cellClass' } }, initialWidth: 140 },
    { label: 'Demand Invoice Value', fieldName: 'DemandInvoiceValue', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 190 },
    { label: 'Receipt Amount', fieldName: 'ReceiptAmt', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 140 },
    { label: 'Interest Due', fieldName: 'InterestDue', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 120 },
    { label: 'Interest Paid', fieldName: 'InterestPaidOrTotalInterestReceived', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 140 },
    { label: 'Prev. Principal Due', fieldName: 'PrevDuePrincipleOnly', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 180 },
    { label: 'Basic Construction Cost', fieldName: 'BasicConstructionCost', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 200 },
    { label: 'BESCOM & BWSSB Charges', fieldName: 'BESCOMAndBWSSBCharges', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 150 },
    { label: 'Club Membership Fees', fieldName: 'ClubMembershipFee', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 180 },
    { label: 'Land Cost', fieldName: 'LandCost', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 140 },
    { label: 'Legal Fees', fieldName: 'LegalFees', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 120 },
    { label: 'Maintenance Deposit', fieldName: 'MaintenanceDeposit', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 180 },
    { label: 'Taxable Amt [CGST 9% OT (9.000 %)]', fieldName: 'OthrChrgCgstTaxableAmt', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 280 },
    { label: 'Taxable Amt [SGST 9% OT (9.000 %)]', fieldName: 'OthrChrgSgstTaxableAmt', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 280 },
    { label: 'CGST 9% OT (9.000 %)', fieldName: 'CGSTOnOtherChrg', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 200 },
    { label: 'SGST 9% OT (9.000 %)', fieldName: 'SGSTOnOtherChrg', type: 'currency', cellAttributes: { class: { fieldName: 'cellClass' } }, initialWidth: 200 },
    {label: '', fieldName: '', initialWidth: 0}
];

@track startDate;
@track endDate;
@track pageNumber = 1;
@track pageSize = 10;
@track totalRecords = 0;
@track totalPages = 0;
@track loading = false;
isCssLoaded = false;
showReceipts = false;
displayMessage = 'Please select Start Date and End Date';

renderedCallback() {
    if (this.isCssLoaded) return;
    this.isCssLoaded = true;
    loadStyle(this, CUSTOM_DT_STYLE)
        .then(() => console.log('Custom CSS loaded'))
        .catch(error => console.error('Error loading CSS', error));
}

get disablePrevious() {
    return this.pageNumber === 1;
}

get disableNext() {
    return this.pageNumber === this.totalPages || this.totalPages === 0;
}

handleStartDateChange(event) {
    this.startDate = event.target.value;
}

handleEndDateChange(event) {
    this.endDate = event.target.value;
}

handleSearch() {
    this.pageNumber = 1;
    this.fetchReceipts();
}

handlePrevious() {
    if (!this.disablePrevious) {
        this.pageNumber--;
        this.fetchReceipts();
    }
}

handleNext() {
    if (!this.disableNext) {
        this.pageNumber++;
        this.fetchReceipts();
    }
}
handleClose(){
this.showReceipts = false;
}

async fetchReceipts() {
    if (!this.startDate || !this.endDate) {
        this.showToast('Error', 'Please select both start and end dates', 'error');
        this.displayMessage = 'Please select both start and end dates';
        return;
    }
    this.showReceipts = false;
    this.loading = true;
    try {
        const response = await getPaymentReceipts({
            startDate: this.startDate,
            endDate: this.endDate,
            pageNumber: this.pageNumber,
            pageSize: this.pageSize
        });

        if(response.records.length > 0){
            this.showReceipts = true;
        }
        if(this.receipts.length === 0){
            this.displayMessage = 'No records found for selected date range';
        }
        // Numeric columns for totals
        
        const totalCols = [
            'BasicConstructionCost','BESCOMAndBWSSBCharges','ClubMembershipFee','LandCost','LegalFees',
            'MaintenanceDeposit','OthrChrgCgstTaxableAmt','OthrChrgSgstTaxableAmt','CGSTOnOtherChrg','SGSTOnOtherChrg'
        ];

        // Calculate totals row
        const totalRow = { Project: 'Total', cellClass: 'dtTotalRow' };
        totalCols.forEach(col => {
        totalRow[col] = response.records.reduce((sum, r) => sum + (r[col] || 0), 0);
        });

        // Transform address field
        this.receipts = response.records.map(rec => {
        let formattedAddress = '';
        if (rec.CustomerAddressBilling) {
            const addr = rec.CustomerAddressBilling;
            formattedAddress = [
                addr.street,
                addr.city,
                addr.state,
                addr.postalCode,
                addr.country
            ].filter(Boolean).join(', ');
        }

        return {
            ...rec,
            CustomerAddressBillingFormatted: formattedAddress
        };
        });

        // Append totals row
        this.receipts = [...this.receipts, totalRow];

        this.totalRecords = response.totalRecords;
        this.pageNumber = response.pageNumber;
        this.totalPages = response.totalPages;

    } catch (error) {
        console.error(JSON.stringify(error));
        this.showReceipts = false;
        this.displayMessage = 'Unbale to fetch receipts for selected date range';
        this.showToast('Error', error.body?.message || 'Something went wrong', 'error');
    } finally {
        this.loading = false;
    }
}

showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
}
}