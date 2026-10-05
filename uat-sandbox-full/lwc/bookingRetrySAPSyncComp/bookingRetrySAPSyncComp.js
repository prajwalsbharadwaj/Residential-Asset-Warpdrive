import { LightningElement, api, track, wire } from 'lwc';
import retrievSobjectName from '@salesforce/apex/RetrySapSyncController.getObjectApiName';
import RetryBookingCalloutToSap from '@salesforce/apex/RetrySapSyncController.RetryBookingCalloutToSAP';
import RetryAccountCalloutToSap from '@salesforce/apex/RetrySapSyncController.RetryAccountCalloutToSap';
// HIGHLIGHT 1: Add these 3 new imports
// =================================================================================
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ACCOUNT_RECORD_TYPE_DEV_NAME from '@salesforce/schema/Account.RecordType.DeveloperName';
import RetryChannelPartnerCalloutToSap from '@salesforce/apex/RetrySapSyncController.RetryChannelPartnerCalloutToSap';
import RetryPaymentReceiptCalloutToSap from '@salesforce/apex/RetrySapSyncController.RetryPaymentReceiptCalloutToSap';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class BookingRetrySAPSyncComp extends LightningElement {
@api recordId; 
objectApiName;
message = '';
loading = true;
isSuccess = false;
isError = false;
milestoneCode = '';

// =================================================================================
// HIGHLIGHT 2: Add this new property to store the record type name
// =================================================================================
accountRecordTypeDeveloperName;

@wire(retrievSobjectName, {recordId : '$recordId'})
sobjectName({data, error}){
if(data){
    console.log('Object Api Name --> ', data);
    this.objectApiName = data;
}else if(error){
    console.log('error in fetching object name --> ', error);
}
}

 // HIGHLIGHT 3: Add this new wire service to get the Record Type
    // The setTimeout gives this wire service time to complete before the logic runs.
    // =================================================================================
    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_RECORD_TYPE_DEV_NAME] })
    wiredAccount({ data, error }) {
        if (data) {
            this.accountRecordTypeDeveloperName = getFieldValue(data, ACCOUNT_RECORD_TYPE_DEV_NAME);
        } else if (error) {
            console.error('Could not get record type', error);
        }
    }

connectedCallback() {
// Add 3 second (3000 ms) delay before calling Apex
setTimeout(() => {
console.log('recordId --> ', this.recordId);
this.retrySAPCallout();
}, 2000);
}

retrySAPCallout() {
if (!this.recordId) {
    this.loading = false;
    this.isError = true;
    this.message = 'No record(s) found.';
    return;
}
// Call methods based on object api name
 switch (this.objectApiName){
    case 'Booking__c' :
        this.bookingRetrySapSync();
        break;
    case 'Account' :
        if (this.accountRecordTypeDeveloperName === 'Channel_Partner_Residential') {
                    this.channelPartnerRetrySapSync();
        } else {
                    this.AccountRetrySapSync();
              } 
                break;
    case 'Payment_Receipt__c' :
        this.PaymentReceiptRetrySapSync();
        break;
 }
}


// Booking Retry Callout
bookingRetrySapSync(){
    console.log('Booking callout');
    RetryBookingCalloutToSap({ bookingId: this.recordId })
    .then(result => {
        this.loading = false;
        console.log('bookingRetrySapSync Result --> ', result);
        if (result && typeof result === 'object') {
        if(result.resp === true){
            this.isSuccess = true;
            this.message = result.responseMessage;
            this.showToast('Success', 'Booking synced with SAP successfully please check the response in `SAP Sync Message`', 'success');
        }else if(result.resp === false){
            this.isError = true;
            this.message = result.responseMessage;
            this.showToast('Error','SAP sync failed for this booking', 'error');
            if(result.responseMessage == null || result.responseMessage == '' || result.responseMessage == undefined){
                this.closeQuickAction();
            }
        }
    }
    })
    .catch(error => {
        console.log('error --> ', error);
        this.showToast('SAP Sync', 'Unexpected error occured please contact your administrator!', 'error');
        this.loading = false;
        this.isError = true;
        this.message = error.body.message;
        if(error.body.message == null || error.body.message == '' || error.body.message == undefined){
                this.closeQuickAction();
            }
    })
}

//Account Retry Callout
AccountRetrySapSync(){
    console.log('Account callout')
    RetryAccountCalloutToSap({accountId: this.recordId})
    .then(result => {
        this.loading = false;
        console.log('AccountRetrySapSync result --> ', result);
        if (result && typeof result === 'object') {
        if(result.resp === true){
            this.isSuccess = true;
            this.message = result.responseMessage;
            this.showToast('Success', 'Account synced with SAP successfully please check the response in `SAP Sync Message`', 'success');
        }else if(result.resp === false){
            this.isError = true;
            this.message = result.responseMessage;
            this.showToast('Error','SAP sync failed for this account', 'error');
            if(result.responseMessage == null || result.responseMessage == '' || result.responseMessage == undefined){
                this.closeQuickAction();
            }
        }
    }
    })
    .catch(error => {
        console.log('error --> ', error);
        this.showToast('SAP Sync', 'Unexpected error occured please contact your administrator!', 'error');
        this.loading = false;
        this.isError = true;
        this.message = error.body.message;
        if(error.body.message == null || error.body.message == '' || error.body.message == undefined){
                this.closeQuickAction();
            }
    })
}
// Channel Partner Retry Callout.
channelPartnerRetrySapSync() {
        console.log('Channel Partner callout');
        RetryChannelPartnerCalloutToSap({ accountId: this.recordId })
            .then(result => {
                this.loading = false;
                console.log('channelPartnerRetrySapSync result --> ', result);
                if (result && typeof result === 'object') {
                    if (result.resp === true) {
                        this.isSuccess = true;
                        this.message = result.responseMessage;
                        this.showToast('Success', 'Channel Partner synced with SAP successfully please check the response in `SAP Sync Message`', 'success');
                    } else if (result.resp === false) {
                        this.isError = true;
                        this.message = result.responseMessage;
                        this.showToast('Error', 'SAP sync failed for this Channel Partner', 'error');
                        if (result.responseMessage == null || result.responseMessage == '' || result.responseMessage == undefined) {
                            this.closeQuickAction();
                        }
                    }
                }
            })
            .catch(error => {
                console.log('error --> ', error);
                this.showToast('SAP Sync', 'Unexpected error occured please contact your administrator!', 'error');
                this.loading = false;
                this.isError = true;
                this.message = error.body.message;
                if (error.body.message == null || error.body.message == '' || error.body.message == undefined) {
                    this.closeQuickAction();
                }
            })
    }

// Payment Receipt Retry Callout.
PaymentReceiptRetrySapSync(){
RetryPaymentReceiptCalloutToSap({receiptId: this.recordId})
.then(result=>{
this.loading = false;
        console.log('PaymentReceiptRetrySapSync result --> ', result);
        if (result && typeof result === 'object') {
        if(result.resp === true){
            this.isSuccess = true;
            this.message = result.responseMessage;
            this.showToast('Success', 'Payment Receipt synced with SAP successfully please check the response in `SAP Sync Message`', 'success');
        }else if(result.resp === false){
            this.isError = true;
            this.message = result.responseMessage;
            this.showToast('Error','SAP sync failed for this receipt', 'error');
            if(result.responseMessage == null || result.responseMessage == '' || result.responseMessage == undefined){
                this.closeQuickAction();
            }
        }
    }
    })
    .catch(error => {
        console.log('error --> ', error);
        this.showToast('SAP Sync', 'Unexpected error occured please contact your administrator!', 'error');
        this.loading = false;
        this.isError = true;
        this.message = error.body.message;
        if(error.body.message == null || error.body.message == '' || error.body.message == undefined){
                this.closeQuickAction();
            }
    })

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

closeQuickAction() {
    this.dispatchEvent(new CloseActionScreenEvent());
}
}