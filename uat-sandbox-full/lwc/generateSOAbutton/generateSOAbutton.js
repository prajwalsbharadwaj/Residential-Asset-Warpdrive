import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";
import getReceiptDateBounds from "@salesforce/apex/SOAStatementController.getReceiptDateBounds";

export default class GenerateSOAbutton extends LightningElement {
  @api recordId;
  @track startDate;
  @track endDate;

  @wire(getReceiptDateBounds, { bookingId: "$recordId" })
  wiredgetReceiptDateBounds({ error, data }){
    if (data) {
        if (data.firstDate) {
          this.startDate = data.firstDate;
        }
        if (data.lastDate) {
          this.endDate = data.lastDate;
        }
      }
     else if (error) {
      this.setDefaults();
    }
  }
  setDefaults() {
    if (!this.endDate) {
      this.endDate = new Date().toISOString().split('T')[0];
    }
    if (!this.startDate) {
      this.startDate = this.endDate;
    }
  }

  // Handle Start Date Change
  handleStartDateChange(event) {
    this.startDate = event.target.value;
  }

  // Handle End Date Change
  handleEndDateChange(event) {
    this.endDate = event.target.value;
  }

  // Close Modal
  handleClose() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  // Generate Statement of Account
  handleSuccess() {
    if (!this.startDate || !this.endDate) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Please select both Start Date and End Date.",
          variant: "error"
        })
      );
      return;
    }

    // Open VF page in new tab with recordId, startDate, endDate
    window.open(
      `/apex/StatementOfAccountDOC?id=${this.recordId}&startDate=${this.startDate}&endDate=${this.endDate}`,
      "_blank"
    );

    // Close modal & show success toast
    this.dispatchEvent(new CloseActionScreenEvent());
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Success",
        message: "Statement of Account generated.",
        variant: "success"
      })
    );
  }
}