import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPostSaleRequests from '@salesforce/apex/RentResaleWorkspaceController.getPostSaleRequests';

export default class RentResaleLanding extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track records = [];
    @track selectedFilter = 'All';
    @track searchKey = '';

    filterValues = [
        { label: 'All', value: 'All' },
        { label: 'Rental', value: 'Rental' },
        { label: 'Resale', value: 'Resale' },
        { label: 'Open', value: 'Open' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Completed', value: 'Completed' },
        { label: 'Closed', value: 'Closed' },
        { label: 'My Requests', value: 'My Requests' }
    ];

    connectedCallback() {
        this.fetchRecords();
    }

    async fetchRecords() {
        try {
            this.isLoading = true;
            const res = await getPostSaleRequests({ filter: this.selectedFilter });
            this.records = (res || []).map(r => {
                let typeBadgeClass = 'slds-badge ';
                if (r.typeDeveloperName === 'Rental') {
                    typeBadgeClass += 'badge-rental';
                } else {
                    typeBadgeClass += 'badge-resale';
                }

                let statusBadgeClass = 'slds-badge ';
                if (r.status === 'Closed' || r.status === 'Active Lease') {
                    statusBadgeClass += 'slds-theme_success';
                } else if (r.status === 'Rejected') {
                    statusBadgeClass += 'slds-theme_error';
                } else {
                    statusBadgeClass += 'slds-theme_info';
                }

                return {
                    ...r,
                    typeBadgeClass,
                    statusBadgeClass
                };
            });
        } catch (error) {
            this.showToast('Error', error?.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get filterOptions() {
        return this.filterValues.map(f => {
            const isSelected = f.value === this.selectedFilter;
            return {
                ...f,
                buttonClass: `filter-pill-btn ${isSelected ? 'filter-pill-selected' : ''}`
            };
        });
    }

    get filteredRecords() {
        if (!this.searchKey) return this.records;
        const key = this.searchKey.toLowerCase();
        return this.records.filter(r => 
            (r.requestNumber && r.requestNumber.toLowerCase().includes(key)) ||
            (r.unitName && r.unitName.toLowerCase().includes(key)) ||
            (r.ownerName && r.ownerName.toLowerCase().includes(key)) ||
            (r.projectName && r.projectName.toLowerCase().includes(key)) ||
            (r.currentStage && r.currentStage.toLowerCase().includes(key)) ||
            (r.status && r.status.toLowerCase().includes(key))
        );
    }

    get hasRecords() {
        return this.filteredRecords && this.filteredRecords.length > 0;
    }

    get recordCount() {
        return this.filteredRecords ? this.filteredRecords.length : 0;
    }

    handleFilterSelect(event) {
        this.selectedFilter = event.currentTarget.dataset.filter;
        this.fetchRecords();
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleRefresh() {
        this.fetchRecords();
    }

    handleRowClick(event) {
        const reqId = event.currentTarget.dataset.id;
        if (reqId) this.navigateToRecord(reqId);
    }

    handleOpenRecord(event) {
        event.stopPropagation();
        const reqId = event.currentTarget.dataset.id;
        if (reqId) this.navigateToRecord(reqId);
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Rent_Resale_Request__c',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}