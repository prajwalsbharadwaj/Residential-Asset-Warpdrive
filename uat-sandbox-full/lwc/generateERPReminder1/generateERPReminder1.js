import { LightningElement, api } from 'lwc';

export default class GenerateERPReminder1 extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/erpReminder1Doc?bpsId=" + this.recordId + "&docType=Reminder1";
      window.open(url, "_blank");
    }
  }
}