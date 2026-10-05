import { LightningElement, api } from 'lwc';

export default class GenerateERPReminder2 extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/erpReminder2Doc?bpsId=" + this.recordId + "&docType=Reminder2";
      window.open(url, "_blank");
    }
  }
}