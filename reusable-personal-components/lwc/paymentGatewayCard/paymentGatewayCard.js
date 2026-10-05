import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const OPP_FIELDS = ['Opportunity.Name', 'Opportunity.Token_Amount__c', 'Opportunity.Amount'];

export default class PaymentGatewayCard extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track showModal = false;
    @track modalStep = 'INPUT'; // INPUT, PROCESSING, SUCCESS
    @track activeTab = 'UPI'; // UPI, NETBANKING, CARD
    @track selectedBank = 'HDFC Bank';
    @track isPaid = false;
    @track transactionUtr = 'EBZ-2026-9821876';
    @track settlementTimestamp = '23-Sep-2026 02:15 IST';
    @track countdownSeconds = 295;
    @track processingStepText = 'Contacting Easebuzz Gateway...';

    countdownInterval;
    processingTimeout;

    recordData;

    @wire(getRecord, { recordId: '$recordId', layoutTypes: ['Full'] })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordData = data;
            const f = data.fields;
            if (f && f.Token_Amount__c && f.Token_Amount__c.value > 0) {
                this.isPaid = true;
            }
        } else if (error) {
            console.error('Error fetching record in payment gateway', error);
        }
    }

    get customerName() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.Customer__r && f.Customer__r.displayValue) return f.Customer__r.displayValue;
            if (f.Account && f.Account.displayValue) return f.Account.displayValue;
            if (f.Name && f.Name.value) {
                // If named like "Vikram Malhotra - Nikoo Deal", extract the first part
                return f.Name.value.split(' - ')[0];
            }
        }
        return 'Valued Customer';
    }

    get orderReference() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.Name && f.Name.value) {
                const clean = f.Name.value.replace(/[^a-zA-Z0-9]/g, '').substring(0, 10).toUpperCase();
                return `ORD-${clean}`;
            }
        }
        return 'ORD-NIKOO-TK88';
    }

    get isModalInput() {
        return this.modalStep === 'INPUT';
    }

    get isModalProcessing() {
        return this.modalStep === 'PROCESSING';
    }

    get isModalSuccess() {
        return this.modalStep === 'SUCCESS';
    }

    get isTabUpi() {
        return this.activeTab === 'UPI';
    }

    get isTabNetbanking() {
        return this.activeTab === 'NETBANKING';
    }

    get isTabCard() {
        return this.activeTab === 'CARD';
    }

    get tabUpiClass() {
        return this.activeTab === 'UPI' ? 'tab-btn active-tab' : 'tab-btn';
    }

    get tabNetbankingClass() {
        return this.activeTab === 'NETBANKING' ? 'tab-btn active-tab' : 'tab-btn';
    }

    get tabCardClass() {
        return this.activeTab === 'CARD' ? 'tab-btn active-tab' : 'tab-btn';
    }

    get bankHdfcClass() {
        return this.selectedBank === 'HDFC Bank' ? 'bank-item active-bank' : 'bank-item';
    }

    get bankIciciClass() {
        return this.selectedBank === 'ICICI Bank' ? 'bank-item active-bank' : 'bank-item';
    }

    get bankSbiClass() {
        return this.selectedBank === 'State Bank of India' ? 'bank-item active-bank' : 'bank-item';
    }

    get bankAxisClass() {
        return this.selectedBank === 'Axis Bank' ? 'bank-item active-bank' : 'bank-item';
    }

    get countdownFormatted() {
        const mins = Math.floor(this.countdownSeconds / 60);
        const secs = this.countdownSeconds % 60;
        return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }

    openModal() {
        this.showModal = true;
        this.modalStep = 'INPUT';
        this.startCountdown();
    }

    closeModal() {
        this.showModal = false;
        clearInterval(this.countdownInterval);
        clearTimeout(this.processingTimeout);
    }

    selectTabUpi() { this.activeTab = 'UPI'; }
    selectTabNetbanking() { this.activeTab = 'NETBANKING'; }
    selectTabCard() { this.activeTab = 'CARD'; }

    selectBankHdfc() { this.selectedBank = 'HDFC Bank'; }
    selectBankIcici() { this.selectedBank = 'ICICI Bank'; }
    selectBankSbi() { this.selectedBank = 'State Bank of India'; }
    selectBankAxis() { this.selectedBank = 'Axis Bank'; }

    startCountdown() {
        clearInterval(this.countdownInterval);
        this.countdownSeconds = 295;
        this.countdownInterval = setInterval(() => {
            if (this.countdownSeconds > 0) {
                this.countdownSeconds -= 1;
            }
        }, 1000);
    }

    simulatePayment() {
        this.modalStep = 'PROCESSING';
        this.processingStepText = 'Contacting Easebuzz Gateway...';

        this.processingTimeout = setTimeout(() => {
            this.processingStepText = 'Routing to Core Banking Verification...';
            setTimeout(() => {
                this.processingStepText = 'Verifying 3D Secure / UPI Authorization...';
                setTimeout(() => {
                    this.processingStepText = 'Settling ₹5,00,000 into Builder Escrow Account...';
                    setTimeout(() => {
                        this.handlePaymentCompleted();
                    }, 800);
                }, 900);
            }, 900);
        }, 900);
    }

    async handlePaymentCompleted() {
        this.modalStep = 'SUCCESS';
        this.isPaid = true;
        const now = new Date();
        this.settlementTimestamp = now.toLocaleDateString('en-GB') + ' ' + now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + ' IST';
        this.transactionUtr = 'EBZ-' + Math.floor(1000000 + Math.random() * 9000000);

        try {
            if (this.objectApiName === 'Opportunity' && this.recordId) {
                const fields = {};
                fields.Id = this.recordId;
                fields.Token_Payment_Received__c = true;
                await updateRecord({ fields });
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Token Advance Collected',
                    message: `₹5,00,000 successfully captured via Easebuzz Direct Pay. UTR: ${this.transactionUtr}`,
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error updating Opportunity', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Payment Captured (Simulated)',
                    message: `Transaction: ${this.transactionUtr}`,
                    variant: 'success'
                })
            );
        }
    }

    finishSuccess() {
        this.closeModal();
    }

    disconnectedCallback() {
        clearInterval(this.countdownInterval);
        clearTimeout(this.processingTimeout);
    }
}
