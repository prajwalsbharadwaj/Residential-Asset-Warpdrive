import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SimpleInterestCalculator extends LightningElement {
    @track amount = '';
    @track rate = '';
    @track periodType = 'Months';
    @track months = '';
    @track days = '';
    @track interest = 0;
    @track showResult = false;

    periodTypeOptions = [
        { label: 'Days', value: 'Days' },
        { label: 'Months', value: 'Months' }
    ];

    get isDaysSelected() {
        return this.periodType === 'Days';
    }
    get isMonthsSelected() {
        return this.periodType === 'Months';
    }

    get isCalculateDisabled() {
        return !this.amount || !this.rate || (this.periodType === 'Months' ? !this.months : !this.days);
    }

    get formattedPrincipal() {
        if (!this.amount) return '';
        return parseFloat(this.amount).toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
    }

    get resultTimeSummary() {
        if (this.periodType === 'Months') {
            const numMonths = parseInt(this.months, 10);
            return `${numMonths} ${numMonths === 1 ? 'month' : 'months'}`;
        } else {
            const numDays = parseInt(this.days, 10);
            return `${numDays} ${numDays === 1 ? 'day' : 'days'}`;
        }
    }

    handleInputChange(event) {
        const field = event.target.name;
        this[field] = event.target.value;
        this.showResult = false;
    }

    handlePeriodTypeChange(event) {
        this.periodType = event.target.value;
        this.days = '';
        this.months = '';
        this.showResult = false;
    }

    handleCalculate() {
        const principal = parseFloat(this.amount);
        const interestRate = parseFloat(this.rate);
        let timeInYears = 0;
        if (this.periodType === 'Months') {
            timeInYears = (parseFloat(this.months) * 30) / 365;
        } else {
            timeInYears = parseFloat(this.days) / 365;
        }
        if (principal && interestRate && timeInYears) {
            this.interest = (principal * interestRate * timeInYears) / 100;
            this.showResult = true;
        }
    }

    handleReset() {
        this.amount = '';
        this.rate = '';
        this.months = '';
        this.days = '';
        this.interest = 0;
        this.showResult = false;
        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(input => {
            input.setCustomValidity('');
            input.reportValidity();
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: 'dismissable'
            })
        );
    }
}