import { LightningElement, api } from 'lwc';

export default class GenerateFinalCancellationLetter extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/finalCancellationDoc?bookingId=" + this.recordId + "&docType=FinalCancellation";
      window.open(url, "_blank");
    }
  }
}