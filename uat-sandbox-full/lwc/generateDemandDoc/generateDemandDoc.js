import { LightningElement, api } from 'lwc';

export default class GenerateDemandDoc extends LightningElement {
    @api recordId;

    @api invoke() {
        if (this.recordId) {
            const url = '/apex/DemandLetterPDF?id=' + this.recordId;
            window.open(url, '_blank');
        }
    }
}