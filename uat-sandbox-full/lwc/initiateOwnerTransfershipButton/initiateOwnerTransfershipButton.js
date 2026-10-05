/* eslint-disable no-alert */
import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";
import createOwnershipTransfer from "@salesforce/apex/OwnershipTransferController.createOwnershipTransfer";

export default class InitiateOwnerTransfer extends LightningElement {
  @api recordId;
  @api objectApiName;

  @track selectedType = "Account";
  @track newAccountId;
  @track newContactId;
  @track newLeadId;
  @track transferDate;
  @track transferReason;
  @track showConfirm = false;

  get typeOptions() {
    return [
      { label: "Account", value: "Account" },
      // { label: "Lead", value: "Lead" }
    ];
  }

  get isAccountSelected() {
    return this.selectedType === "Account";
  }

  get isContactSelected() {
    return this.selectedType === "Contact";
  }

  get isLeadSelected() {
    return this.selectedType === "Lead";
  }

  handleReasonChange(event) {
    this.transferReason = event.target.value;
  }

  get isSaveDisabled() {
    return (
      !this.transferReason ||
      (this.selectedType === "Account" && !this.newAccountId)
       // || (this.selectedType === "Lead" && !this.newLeadId)
    );
  }

  handleTypeChange(event) {
    this.selectedType = event.detail.value;
    this.newAccountId = null;
    this.newContactId = null;
    this.newLeadId = null;
  }

  handleAccountChange(event) {
    this.newAccountId = event.detail.value?.[0];
  }

  handleLeadChange(event) {
    this.newLeadId = event.detail.value?.[0];
  }

  handleDateChange(event) {
    this.transferDate = event.detail.value;
  }

  handleClose() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  closeConfirm() {
    this.showConfirm = false;
  }

  handleSave() {
    alert("Ownership transfer will be initiated.");
    this.submitTransfer();
  }

  handleError(event) {
    this.showToast(
      "Error",
      event.detail.message || "Form submission error.",
      "error"
    );
  }

  submitTransfer() {
    const payload = {
      parentObjectApiName: this.objectApiName,
      parentRecordId: this.recordId,
      transferType: this.selectedType,
      newAccountId: this.newAccountId,
      newLeadId: this.newLeadId,
      transferDate: this.transferDate,
      transferReason: this.transferReason
    };

    console.log(`Submitting transfer: ${JSON.stringify(payload, null, 2)}`);

    createOwnershipTransfer({ payload: JSON.stringify(payload) })
      .then(() => {
        this.showToast(
          "Success",
          "Ownership transfer initiated and submitted for approval.",
          "success"
        );
        this.dispatchEvent(new CloseActionScreenEvent());
      })
      .catch((error) => {
        this.showToast(
          "Error",
          error.body?.message || "Something went wrong.",
          "error"
        );
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}