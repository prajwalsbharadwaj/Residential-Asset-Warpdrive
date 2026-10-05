import { LightningElement, api } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class NotifySapToGenerateDemand extends LightningElement {
    /** Provided automatically by the framework when invoked from a record page quick action */
    @api recordId;


    /** Headless entry point (per Salesforce headless quick action pattern) */
    @api async invoke() {

        try {
            const fields = { Id: this.recordId };
            fields['Bill_Block__c'] = null;

            await updateRecord({ fields });

            this.toast('Success', `Notification sent successfully.`, 'success');
        } catch (e) {
            const msg = (e && e.body && e.body.message) || e.message || 'Unknown error';
            this.toast('Update failed', msg, 'error');
        } finally {
            this.close();
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}