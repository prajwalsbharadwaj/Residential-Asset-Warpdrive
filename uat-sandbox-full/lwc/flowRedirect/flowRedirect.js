import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class FlowRedirect extends NavigationMixin(LightningElement) {
    @api recordId;
    _hasNavigated = false;

    renderedCallback() {
        if (!this._hasNavigated && this.recordId) {
            this._hasNavigated = true;
            console.log('Redirecting to Record:', this.recordId);
            
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    actionName: 'view'
                }
            });
        }
    }
}