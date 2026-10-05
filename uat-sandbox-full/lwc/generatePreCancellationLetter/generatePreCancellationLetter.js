import { LightningElement, api } from 'lwc';

export default class GeneratePreCancellationLetter extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/preCancellationDoc?bookingId=" + this.recordId + "&docType=PreCancellation";
      window.open(url, "_blank");
    }
  }
}