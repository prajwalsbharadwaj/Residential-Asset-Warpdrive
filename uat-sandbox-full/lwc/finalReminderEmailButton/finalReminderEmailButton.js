/* eslint-disable no-alert */
import { LightningElement, api } from 'lwc';
import sendReminderEmail from '@salesforce/apex/FinalReminderController.sendReminderEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class FinalReminderEmailButton extends LightningElement {
    @api recordId;

    @api invoke() {
        // Ask for confirmation before proceeding
        const userConfirmed = confirm(
            'This will send the final reminder email to the customer.\nDo you want to continue?'
        );

        if (!userConfirmed) {
            // User cancelled — close the action without doing anything
            this.dispatchEvent(new CloseActionScreenEvent());
            return;
        }

        if (!this.recordId) {
            this.showToast('Error', 'Booking Payment Schedule ID not found.', 'error');
            this.dispatchEvent(new CloseActionScreenEvent());
            return;
        }

        sendReminderEmail({ bpsId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Final reminder email sent successfully.', 'success');
            })
            .catch(error => {
                this.showToast(
                    'Error sending reminder email',
                    error?.body?.message || error?.message || 'An unexpected error occurred.',
                    'error'
                );
            })
            .finally(() => {
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}