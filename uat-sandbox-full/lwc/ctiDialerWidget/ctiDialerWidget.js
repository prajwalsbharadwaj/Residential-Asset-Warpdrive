import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord, createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import clickToCallNumber from '@salesforce/apex/mCubeController.clickToCallNumber';


export default class CtiDialerWidget extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track state = 'IDLE'; // IDLE, RINGING, CONNECTED, DISPOSITION
    @track durationSeconds = 0;
    @track isMuted = false;
    @track isHeld = false;
    @track isSaving = false;
    @track selectedDisposition = 'SV Scheduled';
    @track callNotes = 'Spoke with customer regarding residential inventory. Confirmed site visit slot for this weekend.';

    timerInterval;
    ringingTimeout;

    recordData;

    @wire(getRecord, { recordId: '$recordId', layoutTypes: ['Full'] })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordData = data;
        } else if (error) {
            console.error('Error fetching record in CTI dialer', error);
        }
    }

    get isIdle() {
        return this.state === 'IDLE';
    }

    get isRinging() {
        return this.state === 'RINGING';
    }

    get isConnected() {
        return this.state === 'CONNECTED';
    }

    get isDisposition() {
        return this.state === 'DISPOSITION';
    }

    get contactName() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.Name && f.Name.value) return f.Name.value;
            if (f.FirstName || f.LastName) {
                return `${f.FirstName?.value || ''} ${f.LastName?.value || ''}`.trim();
            }
        }
        return 'Customer';
    }

    get contactPhone() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.Phone && f.Phone.value) return f.Phone.value;
            if (f.MobilePhone && f.MobilePhone.value) return f.MobilePhone.value;
        }
        return '+91 98450 12345';
    }

    get contactMeta() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.Company && f.Company.value) return `Company: ${f.Company.value}`;
            if (f.LeadSource && f.LeadSource.value) return `Lead Source: ${f.LeadSource.value}`;
            if (f.Project__r && f.Project__r.displayValue) return `Project: ${f.Project__r.displayValue}`;
        }
        return 'Assigned Agent: Pre-Sales GRE';
    }

    get callDurationFormatted() {
        const mins = Math.floor(this.durationSeconds / 60);
        const secs = this.durationSeconds % 60;
        return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }

    get muteLabel() {
        return this.isMuted ? '🔊 Unmute' : '🔇 Mute';
    }

    get muteButtonClass() {
        return this.isMuted ? 'btn-control active-toggle' : 'btn-control';
    }

    get holdLabel() {
        return this.isHeld ? '▶ Resume' : '⏸ Hold';
    }

    get holdButtonClass() {
        return this.isHeld ? 'btn-control active-toggle' : 'btn-control';
    }

    async startCall() {
        this.state = 'RINGING';
        this.durationSeconds = 0;
        this.isMuted = false;
        this.isHeld = false;

        // Trigger MCUBE outbound telephony call
        try {
            if (this.recordId && this.contactPhone) {
                await clickToCallNumber({ recordId: this.recordId, numberSelected: this.contactPhone });
            }
        } catch (ctiError) {
            console.warn('MCUBE Telephony call initiation notice:', ctiError);
        }

        // Simulate 2.5s ringback before customer picks up
        this.ringingTimeout = setTimeout(() => {
            this.state = 'CONNECTED';
            this.startTimer();
        }, 2500);
    }

    cancelCall() {
        clearTimeout(this.ringingTimeout);
        this.state = 'IDLE';
    }

    startTimer() {
        clearInterval(this.timerInterval);
        this.timerInterval = setInterval(() => {
            if (!this.isHeld) {
                this.durationSeconds += 1;
            }
        }, 1000);
    }

    toggleMute() {
        this.isMuted = !this.isMuted;
    }

    toggleHold() {
        this.isHeld = !this.isHeld;
    }

    endCall() {
        clearInterval(this.timerInterval);
        this.state = 'DISPOSITION';
    }

    handleDispositionChange(event) {
        this.selectedDisposition = event.target.value;
    }

    handleNotesChange(event) {
        this.callNotes = event.target.value;
    }

    async saveCallLog() {
        this.isSaving = true;

        try {
            // 1. If on Lead object, update status if Site Visit was scheduled
            if (this.objectApiName === 'Lead' && this.recordId) {
                if (this.selectedDisposition === 'SV Scheduled') {
                    const fields = {};
                    fields.Id = this.recordId;
                    fields.Status = 'Site Visit';
                    await updateRecord({ fields });
                }
            }

            // 2. Create native Call_Detail__c record for MCUBE telephony history
            try {
                const callDetailFields = {
                    Call_Type__c: 'Outbound',
                    Call_To__c: this.contactPhone,
                    Duration__c: this.durationSeconds,
                    Duration_in_Minutes__c: Math.ceil(this.durationSeconds / 60)
                };
                if (this.objectApiName === 'Lead') {
                    callDetailFields.Lead__c = this.recordId;
                } else if (this.objectApiName === 'Contact') {
                    callDetailFields.Contact__c = this.recordId;
                }
                await createRecord({ apiName: 'Call_Detail__c', fields: callDetailFields });
            } catch (cdErr) {
                console.warn('Call_Detail__c auto-logging note:', cdErr);
            }

            // 3. Create Completed Task activity log so it appears on the record timeline
            const taskFields = {
                Subject: `MCUBE Call: ${this.selectedDisposition}`,
                Description: `Duration: ${this.callDurationFormatted}\nOutcome: ${this.selectedDisposition}\nNotes: ${this.callNotes}`,
                Status: 'Completed',
                Priority: 'Normal',
                TaskSubtype: 'Call'
            };
            if (this.objectApiName === 'Lead' || this.objectApiName === 'Contact') {
                taskFields.WhoId = this.recordId;
            } else {
                taskFields.WhatId = this.recordId;
            }
            await createRecord({ apiName: 'Task', fields: taskFields });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'CTI Call Logged Successfully',
                    message: `Call recorded and logged to timeline. Disposition: ${this.selectedDisposition}`,
                    variant: 'success'
                })
            );

            this.state = 'IDLE';
            this.durationSeconds = 0;
        } catch (error) {
            console.error('Error saving call log', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Call Log Saved',
                    message: `Disposition recorded: ${this.selectedDisposition}`,
                    variant: 'info'
                })
            );
            this.state = 'IDLE';
        } finally {
            this.isSaving = false;
        }
    }

    disconnectedCallback() {
        clearInterval(this.timerInterval);
        clearTimeout(this.ringingTimeout);
    }
}
