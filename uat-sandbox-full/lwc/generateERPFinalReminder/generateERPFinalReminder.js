import { LightningElement, api } from 'lwc';

export default class GenerateERPFinalReminder extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/erpFinalReminderDoc?bpsId=" + this.recordId + "&docType=FinalReminder";
      window.open(url, "_blank");
    }
  }
}