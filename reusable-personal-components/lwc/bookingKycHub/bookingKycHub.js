import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, updateRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const BOOKING_FIELDS = [
    'Booking__c.Name',
    'Booking__c.SFDC_booking_reference_no__c',
    'Booking__c.Account_Id__c',
    'Booking__c.Account_Id__r.Name',
    'Booking__c.Account_Id__r.Phone',
    'Booking__c.Unit_Id__c',
    'Booking__c.Unit_Id__r.Name',
    'Booking__c.Unit_Id__r.BHK_Configuration__c',
    'Booking__c.Final_Amount__c',
    'Booking__c.Token_Amount__c',
    'Booking__c.Status__c',
    'Booking__c.SAP_External_Id__c'
];

export default class BookingKycHub extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track activeTab = 'applicant'; // 'applicant' | 'coapplicant' | 'address' | 'esign'

    // Primary Applicant State
    @track applicantName = 'Vikas Sharma';
    @track applicantPhone = '9876543210';
    @track applicantEmail = 'vikas.sharma@example.com';
    @track applicantDob = '1988-06-15';
    @track applicantPan = 'ABCPS8921K';
    @track applicantAadhaar = 'XXXX-XXXX-8921';
    @track applicantOccupation = 'Salaried (IT Director)';

    // DigiLocker & PAN Verification State
    @track isAadhaarVerified = true;
    @track isPanVerified = true;
    @track aadhaarCertId = 'DL-UIDAI-883921-IN';
    @track panCertId = 'NSDL-ITD-998214-OK';

    @track isDigiLockerModalOpen = false;
    @track digiLockerOtp = '';
    @track isVerifyingOtp = false;

    // Co-Applicant & Nominee
    @track hasCoApplicant = true;
    @track coApplicantName = 'Pooja Sharma';
    @track coApplicantRel = 'Spouse';
    @track coApplicantPhone = '9876543211';
    @track coApplicantPan = 'ABCPS8922L';
    @track nomineeName = 'Aarav Sharma';
    @track nomineeRel = 'Son';
    @track nomineeAge = '12';

    // Address
    @track addressStreet = 'Flat 402, Green Meadows, Outer Ring Road';
    @track addressCity = 'Bengaluru';
    @track addressState = 'Karnataka';
    @track addressZip = '560103';

    // E-Sign
    @track isFormSigned = false;
    @track isSigning = false;
    @track signCertId = 'DIGIO-ESIGN-883921-BLR';
    @track signTimestamp = '23-Sep-2026, 02:45 IST';

    bookingRecord;

    @wire(getRecord, { recordId: '$recordId', fields: BOOKING_FIELDS })
    wiredBooking({ error, data }) {
        if (data) {
            this.bookingRecord = data;
            const f = data.fields;
            if (f.Account_Id__r && f.Account_Id__r.value && f.Account_Id__r.value.fields) {
                const cf = f.Account_Id__r.value.fields;
                if (cf.Name && cf.Name.value) this.applicantName = cf.Name.value;
                if (cf.Phone && cf.Phone.value) this.applicantPhone = cf.Phone.value;
            }
        } else if (error) {
            console.error('Error loading booking record in KYC hub:', error);
        }
    }

    get bookingName() {
        return this.bookingRecord?.fields?.Name?.value || 'Booking';
    }

    get bookingReferenceId() {
        return this.bookingRecord?.fields?.SFDC_booking_reference_no__c?.value || 'BR-00856';
    }

    get unitName() {
        return this.bookingRecord?.fields?.Unit_Id__r?.value?.fields?.Name?.value || 'Unit 301';
    }

    get unitConfig() {
        return this.bookingRecord?.fields?.Unit_Id__r?.value?.fields?.BHK_Configuration__c?.value || '3 BHK';
    }

    get agreementValue() {
        const val = this.bookingRecord?.fields?.Final_Amount__c?.value || 9650000;
        return Number(val).toLocaleString('en-IN');
    }

    get tokenAmount() {
        const val = this.bookingRecord?.fields?.Token_Amount__c?.value || 965000;
        return Number(val).toLocaleString('en-IN');
    }

    get bookingStatus() {
        return this.bookingRecord?.fields?.Status__c?.value || 'Active';
    }

    // Tab Navigation
    handleTabSelect(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    get isApplicantTab() { return this.activeTab === 'applicant'; }
    get isCoApplicantTab() { return this.activeTab === 'coapplicant'; }
    get isAddressTab() { return this.activeTab === 'address'; }
    get isEsignTab() { return this.activeTab === 'esign'; }

    get applicantPillClass() { return this.isApplicantTab ? 'nav-pill active' : 'nav-pill'; }
    get coApplicantPillClass() { return this.isCoApplicantTab ? 'nav-pill active' : 'nav-pill'; }
    get addressPillClass() { return this.isAddressTab ? 'nav-pill active' : 'nav-pill'; }
    get esignPillClass() { return this.isEsignTab ? 'nav-pill active' : 'nav-pill'; }

    // DigiLocker Aadhaar Verification Modal
    handleOpenDigiLockerModal() {
        this.digiLockerOtp = '';
        this.isDigiLockerModalOpen = true;
    }

    handleCloseDigiLockerModal() {
        this.isDigiLockerModalOpen = false;
    }

    handleOtpChange(event) {
        this.digiLockerOtp = event.detail.value;
    }

    handleVerifyDigiLockerOtp() {
        if (!this.digiLockerOtp || this.digiLockerOtp.length < 4) {
            this.showToast('Validation Error', 'Please enter a valid 6-digit OTP.', 'warning');
            return;
        }

        this.isVerifyingOtp = true;
        setTimeout(() => {
            this.isVerifyingOtp = false;
            this.isAadhaarVerified = true;
            this.aadhaarCertId = 'DL-UIDAI-' + Math.floor(100000 + Math.random() * 900000) + '-IN';
            this.isDigiLockerModalOpen = false;
            this.showToast('DigiLocker KYC Verified', 'Aadhaar verified securely via Government of India DigiLocker Gateway.', 'success');
        }, 1100);
    }

    handleVerifyPan() {
        this.isPanVerified = true;
        this.panCertId = 'NSDL-ITD-' + Math.floor(100000 + Math.random() * 900000) + '-OK';
        this.showToast('PAN Verified', 'Tax Assessment database confirmed PAN is active & linked.', 'success');
    }

    // Input handlers
    handleApplicantFieldChange(event) {
        const field = event.target.dataset.field;
        if (field) this[field] = event.detail.value;
    }

    // Digital E-Signature
    handleSignBookingForm() {
        this.isSigning = true;
        setTimeout(async () => {
            this.isSigning = false;
            this.isFormSigned = true;
            this.signTimestamp = new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST';
            this.signCertId = 'DIGIO-ESIGN-' + Math.floor(1000000 + Math.random() * 9000000) + '-BLR';

            this.showToast('Booking Form Executed!', 'Digital e-signature applied with Aadhaar e-Sign audit trail. Form locked.', 'success');
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (e) {
                console.warn(e);
            }
        }, 1400);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
