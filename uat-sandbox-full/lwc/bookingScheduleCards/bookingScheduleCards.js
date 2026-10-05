import { LightningElement, api, track } from 'lwc';
import fetchSnapshot from '@salesforce/apex/BookingScheduleCardsCtrl.fetchSnapshot';
import LOCALE from '@salesforce/i18n/locale';

export default class BookingScheduleInterestView extends LightningElement {
  /** Works on Booking__c page or Booking_Payment_Schedule__c page */
  @api recordId;
  @api objectApiName; // pass from flexipage when possible

  @track cards = [];
  @track totalsRows = [];
  @track summary = { scheduleCount: 0, nextDueFmt: '—' };
  @track openSections = []; // names of sections to open

  asOfDisplay = '';
  isLoading = true;

  get openSectionsName(){
    return this.isLoading ? [] : [...this.openSections];
  }

  connectedCallback() {
    this.load();
  }

  handleRefresh() {
    this.isLoading = true;
    this.load();
  }

  async load() {
    try {
      const payload = await fetchSnapshot({
        recordId: this.recordId,
        objectApiName: this.objectApiName
      });
      this.decorateSnapshot(payload);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Failed to load booking snapshot', err);
      this.cards = [];
      this.totalsRows = [];
      this.summary = { scheduleCount: 0, nextDueFmt: '—' };
      this.asOfDisplay = '';
    } finally {
      this.isLoading = false;
    }
  }

  decorateSnapshot(payload) {
    const nf = new Intl.NumberFormat(LOCALE || 'en-IN', {
      style: 'currency',
      currency: 'INR'
    });

    // ----- Booking totals (header card) -----
    const t = payload || {};
    const rows = [
      { key: 'ti',   label: 'Total Installment Amount:',             value: nf.format(t.totalInstallmentAmount || 0) },
      { key: 'toip', label: 'Total Interest (till today):',          value: nf.format(t.totalInterestTillToday || 0) },
      { key: 'top',  label: 'Total Outstanding Principal:',          value: nf.format(t.totalOutstandingPrincipal || 0) },
      { key: 'tir',  label: 'Total Interest Received (allocated):',  value: nf.format(t.totalInterestReceivedAllocated || 0) },
      { key: 'tpr',  label: 'Total Principal Received:',             value: nf.format(t.totalPrincipalReceived || 0) },
      { key: 'tio',  label: 'Total Interest Outstanding:',           value: nf.format(t.totalInterestOutstanding || 0), valueClass: 'bsiv-strong bsiv-danger' },
      { key: 'taa',  label: 'Total Advance Applied:',                value: nf.format(t.totalAdvanceApplied || 0) },
      { key: 'tiw',  label: 'Total Interest Waived:',                value: nf.format(t.totalInterestWaived || 0) },

      // --- NEW: tax on interest (booking level)
      { key: 'ttt',  label: 'Total Tax on Interest (till today):',   value: nf.format(t.totalTaxOnInterestTillToday || 0) },
      { key: 'ttr',  label: 'Total Tax on Interest Received:',       value: nf.format(t.totalTaxOnInterestReceived || 0) },
      { key: 'tto',  label: 'Total Tax on Interest Outstanding:',    value: nf.format(t.totalTaxOnInterestOutstanding || 0), valueClass: 'bsiv-strong bsiv-danger' }
    ];

    rows.forEach(r => { if (!r.valueClass) r.valueClass = 'bsiv-value'; });
    this.totalsRows = rows;

    this.summary = {
      scheduleCount: payload?.scheduleCount || 0,
      nextDueFmt: payload?.nextDueDate ? this.fmtDate(payload.nextDueDate) : '—'
    };

    // ----- Per-schedule sections -----
    this.cards = (payload?.schedules || []).map((s) => {
      const rows = []; 
      if (s.otherCharges || s.taxOnOtherCharges) {
        const ocVal = s.otherCharges || 0;
        const taxVal = s.taxOnOtherCharges || 0;
        rows.push(
          { key: 'oc', label: 'Other Charges:', value: nf.format(ocVal + taxVal), helpText: `${nf.format(ocVal)} + Tax : ${nf.format(taxVal)}` }
        );
      }
  rows.push(
    { key: 'amt',  label: 'Installment Amount:',                  value: nf.format(s.installmentAmount || 0) },
    { key: 'itd',  label: 'Interest (till today):',               value: nf.format(s.interestTillToday || 0) },

        { key: 'op',   label: 'Outstanding Principal:',               value: nf.format(s.outstandingPrincipal || 0),
          valueClass: (s.outstandingPrincipal || 0) > 0 ? 'bsiv-strong bsiv-danger' : 'bsiv-value' },

        { key: 'ira',  label: 'Interest Received (allocated):',       value: nf.format(s.interestReceivedAllocated || 0) },
        { key: 'pr',   label: 'Principal Received:',                  value: nf.format(s.principalReceived || 0) },

        { key: 'tio',  label: 'Total Interest Outstanding:',          value: nf.format(s.interestOutstanding || 0),
          valueClass: (s.interestOutstanding || 0) > 0 ? 'bsiv-strong bsiv-danger' : 'bsiv-strong bsiv-good' },

        { key: 'adv',  label: 'Advance Applied:',                     value: nf.format(s.advanceApplied || 0) },
        { key: 'iw',   label: 'Interest Waived:',                     value: nf.format(s.interestWaived || 0) },

        // --- NEW: tax on interest (schedule level)
        { key: 'ttd',  label: 'Tax on Interest (till today):',        value: nf.format(s.taxTillToday || 0) },
        { key: 'trcv', label: 'Tax on Interest Received:',            value: nf.format(s.taxReceivedAllocated || 0) },
        { key: 'tto2', label: 'Tax on Interest Outstanding:',         value: nf.format(s.taxOutstanding || 0),
          valueClass: (s.taxOutstanding || 0) > 0 ? 'bsiv-strong bsiv-danger' : 'bsiv-strong bsiv-good' }
  );


      rows.forEach(r => { if (!r.valueClass) r.valueClass = 'bsiv-value'; });

      const badge = this.computeBadge(s);
      return {
        id: s.scheduleId,
        header: `${s.milestoneCode} - ${this.fmtDate(s.dueDate)}`,
        rows,
        badgeText: badge.text,
        badgeClass: badge.className
      };
    });

    // Auto-open: totals + current schedule when on BPS record page
    const current = (payload?.schedules || []).find(r => r.scheduleId === this.recordId);
    // small defer to let the accordion render before setting active sections

    setTimeout(()=>{
      this.openSections = current ? ['__totals__', current.id] : ['__totals__'];
    });

    this.asOfDisplay = payload?.asOfTimestamp
      ? new Date(payload.asOfTimestamp).toLocaleString(LOCALE || 'en-IN')
      : '';
  }

  computeBadge(s) {
    const op = s.outstandingPrincipal || 0;
    const io = s.interestOutstanding || 0;
    const pr = s.principalReceived || 0;
    const adv = s.advanceApplied || 0;

    const today = new Date(); today.setHours(0,0,0,0);
    const due = s.dueDate ? new Date(s.dueDate) : null;

    // fully cleared
    if (op <= 0 && io <= 0) {
        return { text: 'Paid', className: 'bsiv-badge bsiv-badge--success' };
    }

    // past due and still has principal due
    if (due && due < today && op > 0) {
        return { text: 'Overdue', className: 'bsiv-badge bsiv-badge--danger' };
    }

    // not yet due and nothing paid against it
    if ((pr + adv) === 0 && op > 0 && (!due || due >= today)) {
        return { text: 'Upcoming', className: 'bsiv-badge bsiv-badge--info' }; // or --neutral
    }

    // something has been paid (principal or advance) but not fully cleared
    return { text: 'Partially Paid', className: 'bsiv-badge bsiv-badge--warn' };
    }

  fmtDate(d) {
    if (!d) return '—';
    const dt = new Date(d);
    return dt.toLocaleDateString(LOCALE || 'en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}