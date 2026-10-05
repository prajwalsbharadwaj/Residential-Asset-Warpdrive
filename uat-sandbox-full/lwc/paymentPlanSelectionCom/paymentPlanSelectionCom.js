import { LightningElement,api, track } from 'lwc';
import searchPaymentPlans from '@salesforce/apex/PaymentPlanController.searchPaymentPlans';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import getUnitIdFromOpportunity from '@salesforce/apex/PaymentPlanController.getUnitIdFromOpportunity';


export default class PaymentPlanSearch extends NavigationMixin(LightningElement) {

    @api recordId;
    @track searchTerm = '';
    @track paymentPlans = [];
    @track isLoading = false;
    @track selectedRows = [];
    @api objectApiName;

    columns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Description', fieldName: 'Description__c', type: 'text' },
        { label: 'No. Of Installments', fieldName: 'No_Of_Installments__c', type: 'number' }
    ];

    connectedCallback() {
        this.fetchPaymentPlans();
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
        this.fetchPaymentPlans();
    }

    fetchPaymentPlans() {
        this.isLoading = true;
        searchPaymentPlans({ searchTerm: this.searchTerm })
            .then(result => {
                this.paymentPlans = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

//     handleGeneratePDF() {
//     if (this.selectedRows.length !== 1) {
//         this.dispatchEvent(
//             new ShowToastEvent({
//                 title: 'Error',
//                 message: 'Please select exactly one payment plan to generate PDF.',
//                 variant: 'error',
//             })
//         );
//         return;
//     }

//     const selectedPlanId = this.selectedRows[0].Id;

//     this[NavigationMixin.Navigate]({
//         type: 'standard__webPage',
//         attributes: {
//             url: `/apex/SalesOfferPDFPage?paymentPlanId=${selectedPlanId}`
//         }
//     }, true); // true = open in new tab
// }


    async handleGeneratePDF() {
        if (this.selectedRows.length !== 1) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select exactly one payment plan to generate PDF.',
                    variant: 'error',
                })
            );
            return;
        }

        const selectedPlanId = this.selectedRows[0].Id;
        let unitRecordId = this.recordId; // Assume current recordId is the Unit Id

        // // NEW LOGIC: Check if the current object is an Opportunity
        // if (this.objectApiName === 'Opportunity') {
        //     this.isLoading = true;
        //     try {
        //         // Call the Apex method to get the Unit__c ID from the Opportunity record
        //         unitRecordId = await getUnitIdFromOpportunity({ opportunityId: this.recordId });
        //         if (!unitRecordId) {
        //             this.dispatchEvent(
        //                 new ShowToastEvent({
        //                     title: 'Error',
        //                     message: 'This Opportunity is not linked to a Unit. Cannot generate sales offer.',
        //                     variant: 'error',
        //                 })
        //             );
        //             this.isLoading = false;
        //             return;
        //         }
        //     } catch (error) {
        //         this.isLoading = false;
        //         this.dispatchEvent(
        //             new ShowToastEvent({
        //                 title: 'Error fetching Unit ID',
        //                 message: 'An error occurred while fetching the Unit ID from the Opportunity.',
        //                 variant: 'error',
        //             })
        //         );
        //         console.error('Apex Error:', error);
        //         return;
        //     } finally {
        //         this.isLoading = false;
        //     }
        // }

        // Construct the URL with both recordId (Unit) and paymentPlanId
        const url = `/apex/SalesOfferPDFPage?recordId=${this.recordId}&paymentPlanId=${selectedPlanId}`;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: url
            }
        }, true); // true = open in new tab
    }



    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}