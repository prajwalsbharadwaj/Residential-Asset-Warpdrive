import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import NAME_FIELD from '@salesforce/schema/Account.Name';
import RERA_FIELD from '@salesforce/schema/Account.RERA_Number__c';
import BROKERAGE_FIELD from '@salesforce/schema/Account.Brokerage_Percentage__c';
import STATUS_FIELD from '@salesforce/schema/Account.Channel_Partner_Status__c';

const FIELDS = [NAME_FIELD, RERA_FIELD, BROKERAGE_FIELD, STATUS_FIELD];

export default class LaunchBrokerPortalAction extends LightningElement {
    @api recordId;
    @track isLoading = true;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.partnerAccount = {
                name: getFieldValue(data, NAME_FIELD) || 'Channel Partner',
                reraNumber: getFieldValue(data, RERA_FIELD) || 'PRM/KA/RERA/2026/CP8891',
                brokerageRate: getFieldValue(data, BROKERAGE_FIELD) || 2.5,
                status: getFieldValue(data, STATUS_FIELD) || 'Active Verified'
            };
        } else if (error) {
            console.error('Error fetching partner account:', error);
            this.partnerAccount = {
                name: 'Channel Partner',
                reraNumber: 'PRM/KA/RERA/2026/CP8891',
                brokerageRate: 2.5,
                status: 'Active'
            };
        }
    }

    partnerAccount;

    get portalUrl() {
        const cpId = this.recordId || '';
        const rera = this.partnerAccount ? encodeURIComponent(this.partnerAccount.reraNumber) : '';
        const name = this.partnerAccount ? encodeURIComponent(this.partnerAccount.name) : '';
        return `https://prajwalsbharadwaj.github.io/Residential-Asset-Warpdrive/broker-portal/?cpId=${cpId}&rera=${rera}&name=${name}`;
    }

    handleLaunchPortal() {
        if (this.portalUrl) {
            window.open(this.portalUrl, '_blank', 'noopener,noreferrer');
            this.handleClose();
        }
    }

    handleCopyLink() {
        if (navigator.clipboard && this.portalUrl) {
            navigator.clipboard.writeText(this.portalUrl).then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copied!',
                    message: 'Partner portal launch link copied to clipboard.',
                    variant: 'success'
                }));
            });
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}
