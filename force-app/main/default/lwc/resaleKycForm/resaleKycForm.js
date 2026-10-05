import { LightningElement, api } from 'lwc';
import loadForm       from '@salesforce/apex/ResaleKycSiteController.loadForm';
import sendOtp        from '@salesforce/apex/ResaleKycSiteController.sendOtp';
import verifyOtp      from '@salesforce/apex/ResaleKycSiteController.verifyOtp';
import saveProgress   from '@salesforce/apex/ResaleKycSiteController.saveProgress';
import submitForm     from '@salesforce/apex/ResaleKycSiteController.submitForm';
import uploadDocument from '@salesforce/apex/ResaleKycSiteController.uploadDocument';

const STEPS = ['personal', 'kyc', 'resale', 'sign'];

const STEP_LABELS = {
    personal: 'Your Details',
    kyc:      'KYC Documents',
    resale:   'Resale Details',
    sign:     'Declarations & Sign',
};

const AUTOSAVE_MS = 2000;

const MAX_FILE_BYTES = 5 * 1024 * 1024; // 5 MB

function blank() {
    return {
        fullName: '', mobile: '', email: '', pan: '',
        address: '', idType: '', idNumber: '', aadhaar: '',
        bankName: '', loanAmount: '',
        decl1: false, decl2: false, decl3: false, decl4: false,
        sigName: '',
        documents: {},
    };
}

export default class ResaleKycForm extends LightningElement {
    @api token;

    linkToken;
    context;
    d = blank();
    errors = {};

    loading    = true;
    loadError  = null;
    submitting = false;
    submitError = null;
    savedAt    = null;

    // Mobile / OTP step state
    _step       = 'mobile';   // 'mobile' | 'otp' | STEPS[n] | 'submitted'
    mobileInput = '';
    mobileError = '';
    otpInput    = '';
    otpError    = '';
    otpMasked   = '';
    otpCode     = '';         // displayed to buyer since no SMS gateway
    sendingOtp  = false;
    verifyingOtp = false;

    // Document upload state
    _uploads = {};            // { PAN: { name, uploading, error }, ID_Proof: …, Address_Proof: … }

    _autosave;

    // ── URL token wiring ──────────────────────────────────────────────────────

    connectedCallback() {
        try {
            const params = new URLSearchParams(window.location.search);
            const t = params.get('token');
            if (t && !this.linkToken) {
                this.linkToken = t;
                this._load();
            }
        } catch(e) { /* ignore */ }
    }

    wirePageRef(ref) {
        const fromUrl = ref?.state?.token;
        const next = fromUrl || this.token;
        if (next && next !== this.linkToken) {
            this.linkToken = next;
            this._load();
        } else if (!next && this.loading && ref) {
            this.loading = false;
            this.loadError = 'This KYC form link is not valid. Please use the link shared by your relationship manager.';
        }
    }

    @api
    set pageRef(ref) { this.wirePageRef(ref); }
    get pageRef() { return null; }

    // ── Data loading ──────────────────────────────────────────────────────────

    async _load() {
        this.loading = true;
        this.loadError = null;
        try {
            const result = await loadForm({ token: this.linkToken });
            this.context = result.context;
            if (result.data) {
                this.d = Object.assign(blank(), result.data);
            }
            if (this.context?.buyerMobile && !this.d.mobile) {
                this.d = { ...this.d, mobile: this.context.buyerMobile };
            }
            this._step = result.locked ? 'submitted' : 'mobile';
        } catch(e) {
            this.loadError = (e.body?.message || e.message || 'Unable to load form. Please try again.');
        } finally {
            this.loading = false;
        }
    }

    // ── Computed state ────────────────────────────────────────────────────────

    get ready()        { return !this.loading && !this.loadError && !this.isSubmitted; }
    get isMobileStep() { return this._step === 'mobile'; }
    get isOtpStep()    { return this._step === 'otp'; }
    get isFormStep()   { return STEPS.includes(this._step); }
    get isSubmitted()  { return this._step === 'submitted'; }

    get isStepPersonal() { return this._step === 'personal'; }
    get isStepKyc()      { return this._step === 'kyc'; }
    get isStepResale()   { return this._step === 'resale'; }
    get isStepSign()     { return this._step === 'sign'; }

    get isAadhaar()  { return this.d.idType === 'Aadhaar'; }
    get isPassport() { return this.d.idType === 'Passport'; }
    get isVoterId()  { return this.d.idType === 'Voter ID'; }
    get isDL()       { return this.d.idType === 'Driving Licence'; }

    get todayFormatted() {
        return new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });
    }

    get stepper() {
        const currentIdx = STEPS.indexOf(this._step);
        return STEPS.map((id, idx) => ({
            id,
            number: idx + 1,
            label: STEP_LABELS[id],
            done: idx < currentIdx,
            disabled: idx > currentIdx,
            ariaCurrent: id === this._step ? 'step' : null,
            className: [
                'step',
                id === this._step ? 'step--active' : '',
                idx < currentIdx  ? 'step--done'   : '',
            ].filter(Boolean).join(' '),
        }));
    }

    // Document upload helpers
    get panUpload()     { return this._uploads.PAN || {}; }
    get idUpload()      { return this._uploads.ID_Proof || {}; }
    get addrUpload()    { return this._uploads.Address_Proof || {}; }

    // ── Mobile step ───────────────────────────────────────────────────────────

    handleMobileInput(e) {
        this.mobileInput = e.target.value.replace(/\D/g, '').slice(0, 10);
        this.mobileError = '';
    }

    handleMobileKeydown(e) {
        if (e.key === 'Enter') this.handleSendOtp();
    }

    async handleSendOtp() {
        if (this.sendingOtp) return;
        const mobile = this.mobileInput.replace(/\D/g, '');
        if (mobile.length < 10) {
            this.mobileError = 'Please enter a valid 10-digit mobile number.';
            return;
        }
        this.sendingOtp = true;
        this.mobileError = '';
        try {
            const result = await sendOtp({ token: this.linkToken, enteredMobile: mobile });
            this.otpMasked = result.maskedMobile;
            this.otpCode   = result.otpCode;   // shown to buyer since no SMS gateway
            this.d = { ...this.d, mobile };
            this._step = 'otp';
        } catch(e) {
            this.mobileError = e.body?.message || 'Could not send OTP. Please try again.';
        } finally {
            this.sendingOtp = false;
        }
    }

    // ── OTP step ──────────────────────────────────────────────────────────────

    handleOtpInput(e) {
        this.otpInput = e.target.value.replace(/\D/g, '').slice(0, 6);
        this.otpError = '';
    }

    handleOtpKeydown(e) {
        if (e.key === 'Enter') this.handleVerifyOtp();
    }

    async handleVerifyOtp() {
        if (this.verifyingOtp) return;
        if (this.otpInput.length < 4) {
            this.otpError = 'Please enter the 6-digit OTP.';
            return;
        }
        this.verifyingOtp = true;
        this.otpError = '';
        try {
            const ok = await verifyOtp({ token: this.linkToken, enteredCode: this.otpInput });
            if (ok) {
                this._step = STEPS[0];
            } else {
                this.otpError = 'Incorrect OTP. Please check and try again.';
            }
        } catch(e) {
            this.otpError = e.body?.message || 'Verification failed. Please try again.';
        } finally {
            this.verifyingOtp = false;
        }
    }

    handleResendOtp() {
        this.otpInput = '';
        this.otpError = '';
        this._step = 'mobile';
    }

    // ── Field input handlers ──────────────────────────────────────────────────

    handleFieldInput(e) {
        const field = e.target.dataset.field;
        this.d = { ...this.d, [field]: e.target.value };
        if (this.errors[field]) {
            const errs = { ...this.errors };
            delete errs[field];
            this.errors = errs;
        }
        this._scheduleSave();
    }

    handleCheck(e) {
        const field = e.target.dataset.field;
        this.d = { ...this.d, [field]: e.target.checked };
        if (this.errors.declarations) {
            const errs = { ...this.errors };
            delete errs.declarations;
            this.errors = errs;
        }
    }

    handleStepClick(e) {
        const id = e.currentTarget.dataset.id;
        const idx = STEPS.indexOf(id);
        const curr = STEPS.indexOf(this._step);
        if (idx < curr) {
            this._save();
            this._step = id;
        }
    }

    // ── Document upload ───────────────────────────────────────────────────────

    async handleFileChange(e) {
        const docType = e.target.dataset.doctype;
        const file    = e.target.files && e.target.files[0];
        if (!file || !docType) return;

        if (file.size > MAX_FILE_BYTES) {
            this._uploads = { ...this._uploads, [docType]: { name: file.name, error: 'File too large. Maximum size is 5 MB.' } };
            return;
        }

        this._uploads = { ...this._uploads, [docType]: { name: file.name, uploading: true } };

        try {
            const base64 = await this._readAsBase64(file);
            await uploadDocument({
                token:      this.linkToken,
                fileName:   file.name,
                base64Data: base64,
                docType:    docType,
            });
            this._uploads = { ...this._uploads, [docType]: { name: file.name, done: true } };
            // Track uploaded doc names in form data
            const docs = Object.assign({}, this.d.documents, { [docType]: file.name });
            this.d = { ...this.d, documents: docs };
        } catch(err) {
            this._uploads = { ...this._uploads, [docType]: { name: file.name, error: err.body?.message || 'Upload failed. Please try again.' } };
        }
    }

    _readAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload  = () => resolve(reader.result.split(',')[1]);
            reader.onerror = () => reject(new Error('Could not read file.'));
            reader.readAsDataURL(file);
        });
    }

    // ── Navigation ────────────────────────────────────────────────────────────

    handleNext() {
        if (!this._validateStep()) return;
        this._save();
        const idx = STEPS.indexOf(this._step);
        if (idx < STEPS.length - 1) {
            this._step = STEPS[idx + 1];
            this._scrollTop();
        }
    }

    handleBack() {
        const idx = STEPS.indexOf(this._step);
        if (idx > 0) {
            this._step = STEPS[idx - 1];
            this._scrollTop();
        }
    }

    _scrollTop() {
        try { window.scrollTo(0, 0); } catch(e) { /* ignore */ }
    }

    // ── Validation ────────────────────────────────────────────────────────────

    _validateStep() {
        const errs = {};
        const { d, _step } = this;
        if (_step === 'personal') {
            if (!d.fullName?.trim()) errs.fullName = 'Full name is required.';
            if (!d.email?.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(d.email)) errs.email = 'Valid email is required.';
            if (!d.pan?.trim() || !/^[A-Z]{5}[0-9]{4}[A-Z]$/i.test(d.pan)) errs.pan = 'Valid 10-character PAN is required (e.g. ABCDE1234F).';
            if (!d.address?.trim()) errs.address = 'Address is required.';
        }
        if (_step === 'kyc') {
            if (!d.idType) errs.idType = 'Please select an identity proof type.';
            if (!d.idNumber?.trim()) errs.idNumber = 'ID number is required.';
        }
        if (_step === 'sign') {
            if (!d.decl1 || !d.decl2 || !d.decl3 || !d.decl4) errs.declarations = 'Please accept all declarations to proceed.';
            if (!d.sigName?.trim()) errs.sigName = 'Please type your full name to provide your digital signature.';
        }
        this.errors = errs;
        return Object.keys(errs).length === 0;
    }

    // ── Autosave ──────────────────────────────────────────────────────────────

    _scheduleSave() {
        clearTimeout(this._autosave);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._autosave = setTimeout(() => this._save(), AUTOSAVE_MS);
    }

    async _save() {
        if (!this.linkToken || this._step === 'mobile' || this._step === 'otp' || this._step === 'submitted') return;
        try {
            await saveProgress({ token: this.linkToken, dataJson: JSON.stringify(this.d) });
            const now = new Date();
            this.savedAt = 'at ' + now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
        } catch(e) {
            // silent – autosave failure shouldn't block the user
        }
    }

    // ── Submit ────────────────────────────────────────────────────────────────

    async handleSubmit() {
        if (this.submitting) return;
        if (!this._validateStep()) return;
        this.submitting = true;
        this.submitError = null;
        try {
            await submitForm({ token: this.linkToken, dataJson: JSON.stringify(this.d) });
            this._step = 'submitted';
            this._scrollTop();
        } catch(e) {
            this.submitError = e.body?.message || 'Submission failed. Please try again.';
        } finally {
            this.submitting = false;
        }
    }
}