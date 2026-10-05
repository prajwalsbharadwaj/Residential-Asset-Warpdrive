import { LightningElement, api } from 'lwc';

export default class GenerateWelcomeLetter extends LightningElement {
  @api recordId;

  @api invoke() {
    if (this.recordId) {
      const url = "/apex/WelcomeLetter?id=" + this.recordId;
      window.open(url, "_blank");
    }
  }
}