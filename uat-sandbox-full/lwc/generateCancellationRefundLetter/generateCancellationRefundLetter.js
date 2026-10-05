import { LightningElement, api } from 'lwc';

export default class GenerateCancellationRefundLetter extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/cancellationRefundDoc?bookingId=" + this.recordId + "&docType=CancellationRefund";
      window.open(url, "_blank");
    }
  }
}