import { LightningElement, api } from 'lwc';

export default class GenerateERPReminder3 extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/erpReminder3Doc?bpsId=" + this.recordId + "&docType=Reminder3";
      window.open(url, "_blank");
    }
  }
}