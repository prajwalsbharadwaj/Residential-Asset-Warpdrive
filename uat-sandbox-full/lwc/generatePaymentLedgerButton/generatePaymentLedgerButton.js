import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";

export default class GeneratePaymentLedgerButton extends LightningElement {
  @api recordId;
  @track startDate;
  @track endDate = new Date().toISOString().split('T')[0];

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
      `/apex/PaymentLedgerDOC?id=${this.recordId}&startDate=${this.startDate}&endDate=${this.endDate}`,
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