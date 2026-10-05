import { LightningElement, api } from 'lwc';

export default class GeneratCarParkAllotmentLetter extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/carParkAllotmentDoc?bookingId=" + this.recordId + "&docType=CarParkAllotment";
      window.open(url, "_blank");
    }
  }
}