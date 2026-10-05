import { LightningElement, track } from 'lwc';
import getBookings from '@salesforce/apex/DebtorAgeingReportController.getBookings';
import getTowerOptions from '@salesforce/apex/DebtorAgeingReportController.getTowerOptions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import CUSTOM_DT_STYLE from '@salesforce/resourceUrl/customDTStyle';

export default class DebtorAgeingReportComp extends LightningElement {
    @track bookings = [];
    @track towerOptions = [];
    @track selectedTower = '';
    @track loading = false;
    @track pageNumber = 1;
    @track pageSize = 10;
    @track totalPages = 0;
    @track totalRecords = 0;
    showRecords = false;
    displayMessage = 'Please select a Tower';
    isCssLoaded = false;

    columns = [
        { label: 'Customer Code', fieldName: 'CustomerCode', type: 'text', wrapText: true, initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Customer Name', fieldName: 'CustomerName', type: 'text', wrapText: true, initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Contact No.', fieldName: 'ContactNo', type: 'text', wrapText: true, initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Unit No.', fieldName: 'UnitNo', type: 'text', wrapText: true, initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Source of Booking', fieldName: 'SourceOfBooking', type: 'text', wrapText: true, initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Booking Date', fieldName: 'BookingDate', type: 'date', wrapText: true, initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'SBA Area (SqFt)', fieldName: 'SBAAreaSqFt', type: 'number', initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Executive (Owner)', fieldName: 'ExecutiveNameOPPOwner', type: 'text', initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Base Cost (A)', fieldName: 'BaseCostA', type: 'currency', initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Other Charges (B1)', fieldName: 'OtherChargesB1', type: 'currency', initialWidth: 180, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Tax on Base Cost', fieldName: 'TaxAmountOnBaseCost', type: 'currency', initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Tax on Other Charges (B2)', fieldName: 'TaxAmountOnOtherChargesB2', type: 'currency', initialWidth: 210, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Agreement Cost', fieldName: 'AgreementCost', type: 'currency', initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Total Cost (C1 = A+ B1+ B2)', fieldName: 'TotalCostC1', type: 'currency', initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Total Rebate (C2)', fieldName: 'TotalRebateC2', type: 'currency', initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Net Cost After Rebate (C1-C2)', fieldName: 'NetCostAfterRebateAndWaiveOffC', type: 'currency', initialWidth: 240, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Due as on day (Charge Types) (F1) (Principle Due)', fieldName: 'DueAsOnDayF1PrincipleDue', type: 'currency', initialWidth: 320, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Due as on day  (Tax on Principle due)  (F2)', fieldName: 'DueAsOnDayF2TaxOnPrincipleDue', type: 'currency', initialWidth: 300, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Total Received Against event due (Charge Types) (G1)', fieldName: 'TotalReceivedAgainstEventDueG1ChargeTypes', type: 'currency', initialWidth: 350, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Total Received Against event due (Tax) (G2)', fieldName: 'TotalReceivedAgainstEventDueG2Tax', type: 'currency', initialWidth: 310, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Net Due (Charge Types) (F1 - G1)', fieldName: 'NetDueF1MinusG1', type: 'currency', initialWidth: 220, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Net Due (Tax) (F2 - G2)', fieldName: 'NetDueTaxF2MinusG2', type: 'currency', initialWidth: 185, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Total Received Against future event  (Charge Types) (H1)', fieldName: 'TotalReceivedAgainstFutureEventH1', type: 'currency', initialWidth: 390, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Total Outstanding [C-(G1+G2+H1+H2)]', fieldName: 'TotalOutstandingG1G2H1', type: 'currency', initialWidth: 290, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Amt due for 0-30 days', fieldName: 'AmtDue0To30Days', type: 'currency', initialWidth: 180, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Amt due for 31-60 days', fieldName: 'AmtDue31To60Days', type: 'currency', initialWidth: 185, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Amt due for 61-90 days', fieldName: 'AmtDue61To90Days', type: 'currency', initialWidth: 185, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Amt due for 91-180 days', fieldName: 'AmtDue91To180Days', type: 'currency', initialWidth: 195, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Amt due for 181-365 days', fieldName: 'AmtDue180To365Days', type: 'currency', initialWidth: 200, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Amt due for > 365 days', fieldName: 'AmtDueMoreThan365Days', type: 'currency', initialWidth: 185, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Actual Due as on Date', fieldName: 'ActualDueAsOnDate', type: 'currency', initialWidth: 180, cellAttributes: { class: { fieldName: 'cellClass' } } },
        { label: 'Last Action taken', fieldName: 'LastActionTaken', type: 'text', initialWidth: 150, cellAttributes: { class: { fieldName: 'cellClass' } } }
    ];

    connectedCallback() {
        this.loadTowerOptions();
    }

    async loadTowerOptions() {
        try {
            this.loading = true;
            const result = await getTowerOptions();
            this.towerOptions = result.map(t => ({ label: t, value: t }));
        } catch (error) {
            this.showToast('Error', 'Failed to load tower options', 'error');
        } finally {
            this.loading = false;
        }
    }

    handleTowerChange(event) {
        this.selectedTower = event.detail.value;
    }

    renderedCallback() {
        if (this.isCssLoaded) return;
        this.isCssLoaded = true;
        loadStyle(this, CUSTOM_DT_STYLE)
            .then(() => console.log('Custom CSS loaded'))
            .catch(error => console.error('Error loading CSS', error));
    }

    async fetchBookings() {
        if (!this.selectedTower) {
            this.showToast('Error', 'Please select a Tower first', 'error');
            this.displayMessage = 'Please select a Tower first';
            return;
        }

        this.showRecords = false;
        this.loading = true;

        try {
            const response = await getBookings({
                towerName: this.selectedTower,
                pageNumber: this.pageNumber,
                pageSize: this.pageSize
            });

            if (response.bookings.length > 0) {
                this.showRecords = true;
            }

            this.bookings = [...response.bookings];
            this.totalRecords = response.totalRecords;
            this.pageNumber = response.pageNumber;
            this.totalPages = response.totalPages;

            if (this.bookings.length > 0) {
                this.appendTotalRow();
            } else {
                this.showToast('Info', 'No records found for selected Tower', 'info');
                this.displayMessage = 'No records found for selected Tower';
            }
        } catch (error) {
            console.error(error);
            this.displayMessage = 'Unable to fetch bookings for selected tower';
            this.showToast('Error', error.body?.message || 'Something went wrong', 'error');
        } finally {
            this.loading = false;
        }
    }

    appendTotalRow() {
        const total = {};
        const currencyFields = [
            'BaseCostA', 'OtherChargesB1', 'TaxAmountOnBaseCost', 'TaxAmountOnOtherChargesB2',
            'AgreementCost', 'TotalCostC1', 'TotalRebateC2', 'NetCostAfterRebateAndWaiveOffC',
            'DueAsOnDayF1PrincipleDue', 'DueAsOnDayF2TaxOnPrincipleDue',
            'TotalReceivedAgainstEventDueG1ChargeTypes', 'TotalReceivedAgainstEventDueG2Tax',
            'NetDueF1MinusG1', 'NetDueTaxF2MinusG2',
            'TotalReceivedAgainstFutureEventH1', 'TotalOutstandingG1G2H1',
            'AmtDue0To30Days', 'AmtDue31To60Days', 'AmtDue61To90Days',
            'AmtDue91To180Days', 'AmtDue180To365Days', 'AmtDueMoreThan365Days',
            'ActualDueAsOnDate'
        ];

        currencyFields.forEach(field => {
            total[field] = this.bookings.reduce((sum, rec) => sum + (rec[field] || 0), 0);
        });

        total.CustomerCode = 'TOTAL';
        total.Id = 'totalRow';
        total.cellClass = 'dtTotalRow';

        this.bookings = [...this.bookings, total];
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.fetchBookings();
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.fetchBookings();
        }
    }

    handleClose() {
        this.showRecords = false;
    }

    get isPrevDisabled() {
        return this.pageNumber <= 1;
    }

    get isNextDisabled() {
        return this.pageNumber >= this.totalPages;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}