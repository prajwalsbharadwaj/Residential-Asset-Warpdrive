import { LightningElement, api } from "lwc";

export default class GenerateTransactionReport extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/TransactionReportDoc?bookingId=" + this.recordId;
      window.open(url, "_blank");
    }
  }
}