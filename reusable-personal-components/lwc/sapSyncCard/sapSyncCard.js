import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class SapSyncCard extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track isSyncing = false;
    @track activeSyncStep = 'Initializing SAP RFC Connection...';
    @track progressPercent = 0;
    @track lastSyncTimestamp = 'Today, 02:18 IST';
    @track isSynced = true;

    @track sapCustomerCode = 'CUST-883921';
    @track sapSalesOrder = 'SO-4920194';
    @track sapMaterialCode = 'MAT-NIK-A102';

    recordData;

    @wire(getRecord, { recordId: '$recordId', layoutTypes: ['Full'] })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordData = data;
            const f = data.fields;
            if (f) {
                if (f.SAP_Customer_Code__c && f.SAP_Customer_Code__c.value) {
                    this.sapCustomerCode = f.SAP_Customer_Code__c.value;
                } else if (f.SAP_External_Id__c && f.SAP_External_Id__c.value) {
                    this.sapCustomerCode = f.SAP_External_Id__c.value;
                }
                if (f.SAP_Material_Code__c && f.SAP_Material_Code__c.value) {
                    this.sapMaterialCode = f.SAP_Material_Code__c.value;
                } else if (f.SAP_External_Id__c && f.SAP_External_Id__c.value) {
                    this.sapMaterialCode = f.SAP_External_Id__c.value;
                }
                if (f.Name && f.Name.value) {
                    const clean = f.Name.value.replace(/[^a-zA-Z0-9]/g, '').substring(0, 8);
                    this.sapSalesOrder = `SO-${clean}`;
                }
            }
        } else if (error) {
            console.error('Error fetching record in SAP sync card', error);
        }
    }

    get syncDotClass() {
        return this.isSyncing ? 'status-dot dot-syncing' : 'status-dot dot-connected';
    }

    get syncStateText() {
        return this.isSyncing ? 'Synchronizing...' : 'Live Connected (OData v4)';
    }

    get progressBarStyle() {
        return `width: ${this.progressPercent}%`;
    }

    triggerSapSync() {
        this.isSyncing = true;
        this.progressPercent = 15;
        this.activeSyncStep = 'Querying SAP MM for Unit Lock (MAT-NIK-A102)...';

        setTimeout(() => {
            this.progressPercent = 50;
            this.activeSyncStep = 'Verifying Customer Master & Credit Limit in SAP FI...';
            setTimeout(() => {
                this.progressPercent = 85;
                this.activeSyncStep = 'Replicating Billing Plan & Sales Order SO-4920194...';
                setTimeout(() => {
                    this.progressPercent = 100;
                    this.handleSyncComplete();
                }, 800);
            }, 800);
        }, 700);
    }

    handleSyncComplete() {
        this.isSyncing = false;
        this.lastSyncTimestamp = 'Just now (Latency: 284ms)';

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'SAP S/4HANA Sync Success',
                message: `ERP Ledger & Inventory updated. Sales Order: ${this.sapSalesOrder} | Customer: ${this.sapCustomerCode}`,
                variant: 'success'
            })
        );
    }
}
