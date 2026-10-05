import { LightningElement, api } from "lwc";

export default class OwnershipTransferAlert extends LightningElement {
  @api recordId;
  @api objectApiName;

  get objectLabel() {
    if (this.objectApiName === "Booking__c") {
      return "booking";
    }
    return "opportunity";
  }
}