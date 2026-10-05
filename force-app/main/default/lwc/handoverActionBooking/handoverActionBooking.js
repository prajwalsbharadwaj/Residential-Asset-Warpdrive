import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import BOOKING_FIELD from '@salesforce/schema/Handover__c.Booking__c';

export default class HandoverActionBooking extends NavigationMixin(LightningElement) {
    @api recordId;
    hasNavigated = false;

    @wire(getRecord, { recordId: '$recordId', fields: [BOOKING_FIELD] })
    wiredHandover({ data, error }) {
        if (data && !this.hasNavigated) {
            const bookingId = getFieldValue(data, BOOKING_FIELD);
            if (bookingId) {
                this.hasNavigated = true;
                this.dispatchEvent(new CloseActionScreenEvent());
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: bookingId,
                        objectApiName: 'Booking__c',
                        actionName: 'view'
                    }
                });
            }
        }
    }
}
