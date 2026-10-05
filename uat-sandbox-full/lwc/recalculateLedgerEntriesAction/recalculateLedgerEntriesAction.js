import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import startRecalculation from '@salesforce/apex/BookingLedgerRecalcController.startRecalculation';
import processReceipt from '@salesforce/apex/BookingLedgerRecalcController.processReceipt';

export default class RecalculateLedgerEntriesAction extends LightningElement {
  @api recordId;

  isWorking = false;
  isCompleted = false;
  total = 0;
  processed = 0;
  receiptIds = [];

  get progressValue() {
    if (!this.total) return 0;
    return Math.min(100, Math.round((this.processed / this.total) * 100));
  }

  get showProgress() {
    return this.total > 0 && (this.isWorking || this.isCompleted);
  }

  get statusText() {
    if (!this.total) return 'No receipts to process.';
    if (this.isCompleted) return `Completed ${this.processed} of ${this.total}.`;
    return `Processing ${this.processed} of ${this.total}...`;
  }

  get canStart() {
    return !this.isWorking && !this.isCompleted;
  }

  get startDisabled() {
    return !this.canStart;
  }

  handleClose() {
    this.dispatchEvent(new CloseActionScreenEvent());
    setTimeout(() => {
      window.location.reload();
    }, 1000);
  }

  async handleStart() {
    this.isWorking = true;
    this.isCompleted = false;
    this.processed = 0;
    this.total = 0;
    this.receiptIds = [];

    try {
      const result = await startRecalculation({ bookingId: this.recordId });
      this.receiptIds = result && result.receiptIds ? result.receiptIds : [];
      this.total = this.receiptIds.length;

      if (this.total === 0) {
        this.isWorking = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'No Receipts',
            message: 'There are no receipts to process for this booking.',
            variant: 'info'
          })
        );
        return;
      }

      for (let i = 0; i < this.receiptIds.length; i += 1) {
        await processReceipt({
          bookingId: this.recordId,
          receiptId: this.receiptIds[i]
        });
        this.processed = i + 1;
      }

      this.isWorking = false;
      this.isCompleted = true;
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Success',
          message: 'Ledger entries recalculated successfully.',
          variant: 'success'
        })
      );
    } catch (error) {
      this.isWorking = false;
      const message = this.reduceError(error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Error',
          message,
          variant: 'error'
        })
      );
    }
  }

  reduceError(error) {
    if (!error) return 'Unknown error.';
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join(', ');
    }
    if (error.body && typeof error.body.message === 'string') {
      return error.body.message;
    }
    if (typeof error.message === 'string') {
      return error.message;
    }
    return 'Unknown error.';
  }
}