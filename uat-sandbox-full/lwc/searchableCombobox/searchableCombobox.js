import { LightningElement, api, track } from "lwc";

export default class SearchableCombobox extends LightningElement {
    isOpen = false;
    highlightCounter = null;
    _value = "";
    @track displayText = "";
    hasInteracted = false;

    @api messageWhenInvalid = "Please type or select a value";
    @api required = false;

    @api label = "Search";

    @track _options = [];

    @api
    get value() {
        return this._value;
    }

    set value(val) {
        this._value = val;
        const match = this._options.find(opt => opt.value === val);
        this.displayText = match ? match.label : val;
    }

    @api
    get options() {
        return this._options;
    }

    set options(val) {
        this._options = val || [];
    }

    get tempOptions() {
        let options = this.options;
        if (this.displayText) {
            options = this.options.filter((op) =>
                op.label.toLowerCase().includes(this.displayText.toLowerCase())
            );
        }
        return this.highLightOption(options);
    }

    get isInvalid() {
        return this.required && this.hasInteracted && !this._value;
    }

    get formElementClasses() {
        return this.isInvalid ? "slds-form-element slds-has-error" : "slds-form-element";
    }

    get classes() {
        let base = "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click";
        return this.isOpen ? `${base} slds-is-open` : base;
    }

    get inputClasses() {
        let base = "slds-input slds-combobox__input";
        return this.isOpen ? `${base} slds-has-focus` : base;
    }

    handleChange(event) {
        this.displayText = event.target.value;
        this._value = ''; // Clear actual selected value
        this.hasInteracted = false;
        this.fireChange();
    }

    handleInput() {
        this.isOpen = true;
    }

    handleFocus() {
        this._inputHasFocus = true;
        this.isOpen = true;
        this.highlightCounter = null;
        this.dispatchEvent(new CustomEvent("focus"));
    }

    handleBlur() {
        this._inputHasFocus = false;
        if (this._cancelBlur) return;

        this.isOpen = false;
        if (!this._value) this.hasInteracted = true;

        this.highlightCounter = null;
        this.dispatchEvent(new CustomEvent("blur"));
    }

    allowBlur() {
        this._cancelBlur = false;
    }

    cancelBlur() {
        this._cancelBlur = true;
    }

    handleDropdownMouseDown(event) {
        if (event.button === 0) this.cancelBlur();
    }

    handleDropdownMouseUp() {
        this.allowBlur();
    }

    handleDropdownMouseLeave() {
        if (!this._inputHasFocus) this.isOpen = false;
    }

    handleSelect(event) {
        this.isOpen = false;
        this.allowBlur();

        const selectedValue = event.currentTarget.dataset.value;
        const match = this._options.find(opt => opt.value === selectedValue);

        this._value = selectedValue;
        this.displayText = match ? match.label : selectedValue;

        this.fireChange();
    }

    handleKeyDown(event) {
        const list = this.tempOptions;

        if (event.key === "Escape") {
            this.isOpen = false;
            this.highlightCounter = null;
        } else if (event.key === "Enter") {
            if (this.isOpen && this.highlightCounter !== null) {
                this._value = list[this.highlightCounter].value;
                this.displayText = list[this.highlightCounter].label;
                this.fireChange();
                this.isOpen = false;
            }
        } else if (["ArrowDown", "PageDown"].includes(event.key)) {
            this.isOpen = true;
            this.highlightCounter = this.highlightCounter === null ? 0 : this.highlightCounter + 1;
        } else if (["ArrowUp", "PageUp"].includes(event.key)) {
            this.isOpen = true;
            this.highlightCounter =
                this.highlightCounter === null || this.highlightCounter === 0
                    ? list.length - 1
                    : this.highlightCounter - 1;
        }

        if (["ArrowDown", "ArrowUp"].includes(event.key)) {
            this.highlightCounter = Math.abs(this.highlightCounter) % list.length;
        }

        if (event.key === "Home") {
            this.highlightCounter = 0;
        } else if (event.key === "End") {
            this.highlightCounter = list.length - 1;
        }
    }

    highLightOption(options) {
        let base = "slds-media slds-listbox__option slds-listbox__option_plain slds-media_small";
        return options.map((opt, index) => {
            const focused = index === this.highlightCounter;
            return {
                ...opt,
                focused: focused ? "yes" : "",
                classes: focused ? `${base} slds-has-focus` : base
            };
        });
    }

    fireChange() {
        this.dispatchEvent(new CustomEvent("change", {
            detail: {
                value: this._value
            }
        }));
    }

    renderedCallback() {
        this.template.querySelector("[data-focused='yes']")?.scrollIntoView();
    }
}