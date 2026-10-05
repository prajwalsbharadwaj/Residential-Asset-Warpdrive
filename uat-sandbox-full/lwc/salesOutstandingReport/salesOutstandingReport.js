import { LightningElement, track, wire } from 'lwc';
import getDebtorAgeingReport from '@salesforce/apex/SalesOutstandingReportController.getDebtorAgeingReport';
import getProjectAndTowers from '@salesforce/apex/SalesOutstandingReportController.getProjectVsTowerOptions';
export default class SalesOutstandingReport extends LightningElement {

    @track  columns = [
            // These columns are based on the image and Apex DTO structure.
            // Adjust the label and fieldName to match the exact report headings you need.
            { label: 'Cust. Code', fieldName: 'customerCode', type: 'text', initialWidth: 100 },
            { label: 'Customer Name', fieldName: 'customerName', type: 'text', initialWidth: 180 },
            { label: 'Contact No', fieldName: 'contactNo', type: 'text', initialWidth: 120 },
            { label: 'Unit No.', fieldName: 'unitNo', type: 'text', initialWidth: 90 },
            { label: 'Booking Date', fieldName: 'bookingDate', type: 'date', initialWidth: 120 },
            
            // Increased width for multi-word headers
            { label: 'SBA Area (Sq.ft.)', fieldName: 'sbaArea', type: 'number', initialWidth: 150 }, 
            { label: 'Sales Executive', fieldName: 'executiveName', type: 'text', initialWidth: 150 },
            
            // Currency Columns with longer labels
            { label: 'Base Cost (A)', fieldName: 'baseCost', type: 'currency', initialWidth: 150, cellAttributes: { alignment: 'left' } },
            { label: 'Other Chrg (B)', fieldName: 'otherCharges', type: 'currency', initialWidth: 150, cellAttributes: { alignment: 'left' } },
            { label: 'Total Cost (A+B)', fieldName: 'totalCost', type: 'currency', initialWidth: 160, cellAttributes: { alignment: 'left' } },
            { label: 'Tax on Otr. Chrg.', fieldName: 'taxAmountOnOtherCharges', type: 'currency', initialWidth: 150, cellAttributes: { alignment: 'left' } },
            
            // Outstanding/Due/Received Columns
            { label: 'Total Due (Principal)', fieldName: 'totalOutstandingPrincipal', type: 'currency', initialWidth: 180, cellAttributes: { alignment: 'left' } },
            { label: 'Total Due (Interest)', fieldName: 'totalInterestOutstanding', type: 'currency', initialWidth: 170, cellAttributes: { alignment: 'left' } },
            { label: 'Total Received (Principal)', fieldName: 'totalPrincipalReceived', type: 'currency', initialWidth: 190, cellAttributes: { alignment: 'left' } },
            { label: 'Total Received (Interest)', fieldName: 'totalInterestReceived', type: 'currency', initialWidth: 180, cellAttributes: { alignment: 'left' } },
            { label: 'Total Due (P+I)', fieldName: 'totalDue', type: 'currency', initialWidth: 150, cellAttributes: { alignment: 'left' } },
            { label: 'Total Received', fieldName: 'totalReceived', type: 'currency', initialWidth: 150, cellAttributes: { alignment: 'left' } },
            { label: 'Excess Received', fieldName: 'excessReceived', type: 'currency', initialWidth: 150, cellAttributes: { alignment: 'left' } },
            
            // Percentage Column
            { 
                label: '% Amt Rcvd on Ttl Cost', 
                fieldName: 'amountReceivedOnTotalCost', 
                type: 'percent', 
                initialWidth: 160, // Ensure label is visible
                cellAttributes: { alignment: 'left' }, 
                typeAttributes: { minimumFractionDigits: '2', maximumFractionDigits: '2' } 
            },
            
            // Final Outstanding Columns
            { label: 'Outstanding (Principal)', fieldName: 'outstandingPrinciple', type: 'currency', initialWidth: 180, cellAttributes: { alignment: 'left' } },
            { label: 'Outstanding (Interest)', fieldName: 'outstandingInterest', type: 'currency', initialWidth: 170, cellAttributes: { alignment: 'left' } }
        ];
    @track bookings = [];
    @track projectVsTowers = {};
    @track projectOptions = [];
    @track towerOptions = [];
    @track selectedProject;
    @track selectedTower;
    displayMessage;
    @track pageNumber = 1;
    @track pageSize = 10;
    @track totalPages = 0;
    @track totalRecords = 0;
    showRecords = false;
    displayMessage = 'Please select a Project First';

     connectedCallback() {
         this.loadProjectAndTower();
    }

    async loadProjectAndTower() {
        try {
            const result = await getProjectAndTowers();
            this.projectVsTowers = result;

            // Build project combobox options from keys
            this.projectOptions = Object.keys(result).map(key => ({
                label: key,
                value: key
            }));
        } catch (error) {
            console.error('Error fetching projects and towers:', error);
        }
    }

    handleProjectChange(event) {
        this.selectedProject = event.detail.value;

        const towers = this.projectVsTowers[this.selectedProject] || [];
        if(towers.length === 0){
            this.displayMessage = 'There are no towers associated with this Project kindly select another Project';
        }else{
            this.displayMessage = 'Please select the Tower from dropdown and click search';
        }

        // Build tower combobox options dynamically
        this.towerOptions = towers.map(tower => ({
            label: tower,
            value: tower
        }));

        // Reset selected tower when project changes
        this.selectedTower = null;
    }

    handleTowerChange(event) {
        this.selectedTower = event.detail.value;
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
                const response = await getDebtorAgeingReport({
                    projectName : this.selectedProject,
                    towerName : this.selectedTower,
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