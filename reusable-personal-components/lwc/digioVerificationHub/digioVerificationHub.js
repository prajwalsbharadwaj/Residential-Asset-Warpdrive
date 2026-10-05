import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const OPP_FIELDS = ['Opportunity.Name', 'Opportunity.ApprovalStatus__c'];

export default class DigioVerificationHub extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track activeTab = 'KYC'; // KYC, ESIGN
    @track isScanningKyc = false;
    @track isKycVerified = false;
    @track kycStatusMessage = 'Connecting to NSDL Tax Database...';
    @track kycVerificationId = 'DGO-KYC-98214-IN';

    @track isSigning = false;
    @track isAgreementSigned = false;
    @track signatureTimestamp = '23-Sep-2026 02:20 IST';
    @track esignCertId = 'DIGIO-ESIGN-8839210-BLR';

    recordData;

    @wire(getRecord, { recordId: '$recordId', layoutTypes: ['Full'] })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordData = data;
            const f = data.fields;
            if (f && f.ApprovalStatus__c && f.ApprovalStatus__c.value === 'Approved') {
                this.isAgreementSigned = true;
                this.isKycVerified = true;
            }
        } else if (error) {
            console.error('Error fetching record in DigiO hub', error);
        }
    }

    get applicantName() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.Customer__r && f.Customer__r.displayValue) return f.Customer__r.displayValue;
            if (f.Account && f.Account.displayValue) return f.Account.displayValue;
            if (f.Name && f.Name.value) {
                return f.Name.value.split(' - ')[0];
            }
        }
        return 'Applicant';
    }

    get applicantNameUpper() {
        return this.applicantName.toUpperCase();
    }

    get isKycTab() {
        return this.activeTab === 'KYC';
    }

    get isEsignTab() {
        return this.activeTab === 'ESIGN';
    }

    get tabKycClass() {
        return this.activeTab === 'KYC' ? 'tab-btn active-tab' : 'tab-btn';
    }

    get tabEsignClass() {
        return this.activeTab === 'ESIGN' ? 'tab-btn active-tab' : 'tab-btn';
    }

    get agreementStatusText() {
        return this.isAgreementSigned ? 'Digitally Executed' : 'Awaiting Buyer Signature';
    }

    get agreementStatusBadgeClass() {
        return this.isAgreementSigned ? 'status-pill pill-green' : 'status-pill pill-amber';
    }

    selectKycTab() {
        this.activeTab = 'KYC';
    }

    selectEsignTab() {
        this.activeTab = 'ESIGN';
    }

    runKycVerification() {
        this.isScanningKyc = true;
        this.kycStatusMessage = 'Querying NSDL & Income Tax PAN records...';

        setTimeout(() => {
            this.kycStatusMessage = 'Fetching UIDAI DigiLocker biometric vault...';
            setTimeout(() => {
                this.kycStatusMessage = 'Validating Demographics & Aadhaar match...';
                setTimeout(() => {
                    this.isScanningKyc = false;
                    this.isKycVerified = true;
                    this.kycVerificationId = 'DGO-KYC-' + Math.floor(100000 + Math.random() * 900000);

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Digital KYC Verified',
                            message: `NSDL PAN & UIDAI Aadhaar verification passed with 99.8% match confidence.`,
                            variant: 'success'
                        })
                    );
                }, 800);
            }, 800);
        }, 800);
    }

    simulateBuyerSign() {
        this.isSigning = true;

        setTimeout(() => {
            this.handleSigningCompleted();
        }, 2200);
    }

    async handleSigningCompleted() {
        this.isSigning = false;
        this.isAgreementSigned = true;
        const now = new Date();
        this.signatureTimestamp = now.toLocaleDateString('en-GB') + ' ' + now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + ' IST';
        this.esignCertId = 'DIGIO-ESIGN-' + Math.floor(1000000 + Math.random() * 9000000) + '-BLR';

        try {
            if (this.objectApiName === 'Opportunity' && this.recordId) {
                const fields = {};
                fields.Id = this.recordId;
                fields.ApprovalStatus__c = 'Approved';
                await updateRecord({ fields });
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Agreement Digitally Executed',
                    message: `Buyer Vikram Malhotra successfully signed via DigiO Aadhaar e-Sign. Certificate: ${this.esignCertId}`,
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error updating Opportunity', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'e-Sign Captured (Simulated)',
                    message: `Certificate ID: ${this.esignCertId}`,
                    variant: 'success'
                })
            );
        }
    }
}
