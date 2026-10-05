import { LightningElement, api, track } from "lwc";
import getConditionTypePicklistValues from "@salesforce/apex/BookingConditionController.getConditionTypePicklistValues";
import getConditions from "@salesforce/apex/BookingConditionController.getConditions";
import getConditionTypeDefaults from "@salesforce/apex/BookingConditionController.getConditionTypeDefaults";
import upsertConditions from "@salesforce/apex/BookingConditionController.upsertConditions";
import deleteConditions from "@salesforce/apex/BookingConditionController.deleteConditions";
import getParentStage from "@salesforce/apex/BookingConditionController.getParentStage";
import getChargeableArea from "@salesforce/apex/BookingConditionController.getChargeableArea";

// ---- keys used in summary (must match Condition_Type__c values) ----
const KEY_BASE              = 'Base Price';
const KEY_BASE_DISCOUNT     = 'Base Price Discount';
const KEY_CGST_CONSTR       = 'CGST Construction Cost';
const KEY_SGST_CONSTR       = 'SGST Construction Cost';
const KEY_CGST_OTHER        = 'CGST Other Charges';
const KEY_SGST_OTHER        = 'SGST Other Charges';

const OTHER_CHARGE_KEYS = [
  'BESCOM & BWSSB',
  'Club House Membership',
  'Corpus Fund Deposit',
  'Legal charge/Expense'
];

export default class BookingConditionManager extends LightningElement {
  @api recordId;
  @api objectApiName;

  @track readonlyVar = "";
  @track isEditing = false;
  @track isReadOnly = false;
  @track isLoading = true;
  @track message = "";
  @track messageIsError = false;
  @track conditionTypeOptions = [];
  @track rows = [];
  @track initialRows = [];
  @track displayConditionTypes = [];
  @track invalidFields = {};
  @track chargeableArea = '';

  // NEW: totals summary (computed from Amount_By_Type__c)
  @track summary = {
    baseNet: 0,
    hasDiscount: false,
    otherCharges: 0,
    gstConstruction: 0,
    gstOther: 0,
    finalTotal: 0
  };

  // Hardcoded read-only condition types
  static READ_ONLY_TYPES = new Set([
    '1/3 Agreement Value',
    '2/3 Agreement Value',
    'Brokerage Fix Amt'
  ]);

  // Dual inputs (percent + amount)
  static DUAL_VALUE_TYPES = new Set([
    'Base Price Discount'
  ]);

  // Always ensure parentType has a value
  get parentType() {
    return this.objectApiName || "Opportunity";
  }

  get editButtonLabel() {
    return this.isEditing ? "Cancel" : "Edit";
  }

  get editButtonVariant() {
    return this.isEditing ? "brand-outline" : "brand";
  }

  connectedCallback() {
    //console.log('OUTPUT : ',this.objectApiName,' ',this.recordId);
    this.loadAll();
  }

  async loadAll() {
    this.isLoading = true;
    this.message = "";
    this.messageIsError = false;
    try {
      const types = await getConditionTypePicklistValues();
      this.conditionTypeOptions = types.map((e) => ({
        value: e.value || e,
        label: e.label || e.value || e
      }));

      const conds = await getConditions({
        parentId: this.recordId,
        parentType: this.parentType
      });

      const typeDefaults = await getConditionTypeDefaults();

      const byType = {};
      conds.forEach((c) => { byType[c.Condition_Type__c] = c; });

      const basePriceKey = this._findBasePriceKey();
      const baseRec = basePriceKey ? byType[basePriceKey] : byType['Base Price'];
      const basePriceAmount = baseRec ? baseRec.Amount__c : null;

      this.rows = this.conditionTypeOptions.map((opt) => {
        const rec = byType[opt.value];
        const type = rec ? (rec.Type__c || 'Fixed Amount') :
                     (typeDefaults && typeDefaults[opt.value]) ? typeDefaults[opt.value] : 'Fixed Amount';
        const isPercentage = type === 'Percentage';
        const amount = rec ? (isPercentage ? rec.Percentage__c : rec.Amount__c) : '';
        const quantity = rec ? (rec.Quantity__c != null ? rec.Quantity__c : 1) : '';
        const readOnly = this.constructor.READ_ONLY_TYPES.has(opt.label) || this.constructor.READ_ONLY_TYPES.has(opt.value);
        const isDualValue = this.constructor.DUAL_VALUE_TYPES.has(opt.label) || this.constructor.DUAL_VALUE_TYPES.has(opt.value);

        let percent = '';
        if (isDualValue && !isNaN(amount) && amount !== '' && basePriceAmount && Number(basePriceAmount) > 0) {
          percent = (Number(amount) / Number(basePriceAmount)) * 100;
        }

        return {
          key: opt.value,        // Condition_Type__c
          label: opt.label,      // human label
          type,
          isPercentage,
          amount,
          quantity,
          isDualValue,
          percent,
          readOnly,
          amountClass: '',
          quantityClass: '',
          quantityDisabled: type !== 'Rate',
          amountByType: rec?.Amount_By_Type__c || 0
        };
      });

      // Deep copy for Cancel
      this.initialRows = JSON.parse(JSON.stringify(this.rows));

      const stage = await getParentStage({ parentId: this.recordId, parentType: this.parentType });

      if (this.parentType === "Booking__c" && stage && stage.toLowerCase() === "confirmed") {
        this.isReadOnly = true;
        this.readonlyVar = "Booking is Confirmed. Editing is disabled.";
      } else if (this.parentType === "Opportunity" && stage && stage.toLowerCase() === "closed won") {
        this.isReadOnly = true;
        this.readonlyVar = "Opportunity is Closed. Editing is disabled.";
      } else {
        this.isReadOnly = false;
        this.readonlyVar = "";
      }

      await this.fetchChargeableArea();

      this.invalidFields = {};
      this.refreshDisplayRows(); // also recomputes summary

    } catch (e) {
      this.showError(e);
    }
    this.isLoading = false;
  }

  async fetchChargeableArea(){
    try {
      const area = await getChargeableArea({ parentId: this.recordId, parentType: this.parentType });
      this.chargeableArea = area || '';
    } catch (err) {
      // non-fatal
      // eslint-disable-next-line no-console
      console.error("Failed to fetch chargeable area:", err);
    }
  }

  refreshDisplayRows() {
    // Merge validation flags back into rows for rendering
    this.displayConditionTypes = this.rows.map((r) => {
      const inv = this.invalidFields[r.key] || {};
      const percentErrClass = inv.percentError ? 'slds-has-error' : '';
      return {
        value: r.key,
        label: r.label,
        type: r.type,
        isPercentage: r.isPercentage,
        isDualValue: r.isDualValue,
        amount: r.amount !== undefined ? r.amount : '',
        amountByType: r.amountByType,
        percent: r.percent !== undefined ? r.percent : '',
        quantity: r.quantity !== undefined ? r.quantity : (r.amount !== '' ? 1 : ''),
        readOnly: r.readOnly,
        placeholder: r.isPercentage ? 'Enter percentage' : 'Enter amount',
        formatter: r.isPercentage ? null : 'currency',
        max: r.isPercentage ? 100 : null,
        amountClass: inv.amountError ? 'slds-has-error' : '',
        percentClass: percentErrClass,
        percentContainerClass: `slds-col slds-size_1-of-2 slds-grid slds-grid_vertical-align-center ${percentErrClass}`,
        quantityClass: inv.quantityError ? 'slds-has-error' : '',
        quantityDisabled: r.quantityDisabled || r.readOnly
      };
    });

    // recompute totals (from Amount_By_Type__c)
    this._recomputeSummary();
  }

  toggleEdit() {
    if (this.isReadOnly) return;
    this.isEditing = !this.isEditing;
    if (!this.isEditing) {
      this.rows = JSON.parse(JSON.stringify(this.initialRows));
      this.invalidFields = {};
      this.refreshDisplayRows();
    }
  }

  handleAmountChange(event) {
    const key = event.target.dataset.cond;
    const value = event.target.value;
    const row = this.rows.find((r) => r.key === key);
    if (!row) return;

    if (value !== '' && !isNaN(value)) {
      row.amount = parseFloat(value);
    } else {
      row.amount = '';
      row.quantity = '';
    }

    if (row.isPercentage) {
      const n = Number(row.amount);
      const hasError = isNaN(n) || n < 0 || n > 100;
      const existing = this.invalidFields[key] || {};
      if (hasError) {
        this.invalidFields[key] = { ...existing, amountError: true };
      } else if (existing.amountError) {
        const { amountError, ...rest } = existing;
        this.invalidFields[key] = rest;
      }
    }

    if (row.isDualValue) {
      const base = this._getBasePriceAmount();
      if (base && !isNaN(base) && Number(base) > 0 && row.amount !== '' && !isNaN(row.amount)) {
        row.percent = (Number(row.amount) / Number(base)) * 100;
        const existing = this.invalidFields[key] || {};
        const n = Number(row.percent);
        if (!isNaN(n) && n >= 0 && n <= 100) {
          if (existing.percentError) {
            const { percentError, ...rest } = existing;
            this.invalidFields[key] = rest;
          }
        }
      } else {
        row.percent = '';
      }
    }

    this.refreshDisplayRows();
  }

  handleQuantityChange(event) {
    const key = event.target.dataset.cond;
    const value = event.target.value;
    const row = this.rows.find((r) => r.key === key);
    if (!row) return;
    if (value !== '' && !isNaN(value)) {
      row.quantity = parseInt(value, 10);
    } else {
      row.quantity = '';
    }
    this.refreshDisplayRows();
  }

  handlePercentChange(event) {
    const key = event.target.dataset.cond;
    const value = event.target.value;
    const row = this.rows.find((r) => r.key === key);
    if (!row || !row.isDualValue) return;

    if (value !== '' && !isNaN(value)) {
      row.percent = parseFloat(value);
      const base = this._getBasePriceAmount();
      const n = Number(row.percent);
      const hasError = isNaN(n) || n < 0 || n > 100;
      const existing = this.invalidFields[key] || {};
      if (hasError) {
        this.invalidFields[key] = { ...existing, percentError: true };
      } else {
        if (existing.percentError) {
          const { percentError, ...rest } = existing;
          this.invalidFields[key] = rest;
        }
        if (base && !isNaN(base) && Number(base) > 0) {
          row.amount = (Number(base) * n) / 100;
        }
      }
    } else {
      row.percent = '';
    }
    this.refreshDisplayRows();
  }

  async handleSave() {
    this.isLoading = true;
    this.message = "";
    this.invalidFields = {};
    const toUpsert = {};
    const toDelete = [];
    const qtyMap = {};
    const typeMap = {};
    let hasValidationError = false;

    const basePriceType = this.conditionTypeOptions.find(
      (opt) =>
        opt.label.toLowerCase() === "base price" ||
        opt.value.toLowerCase() === "base price"
    );

    if (basePriceType) {
      const baseRow = this.rows.find((r) => r.key === basePriceType.value);
      const basePriceValue = baseRow ? baseRow.amount : '';
      if (
        basePriceValue === undefined ||
        basePriceValue === "" ||
        isNaN(basePriceValue) ||
        Number(basePriceValue) <= 0
      ) {
        this.invalidFields[basePriceType.value] = { amountError: true };
        this.message = "Base Price is required and must be greater than 0.";
        this.messageIsError = true;
        this.refreshDisplayRows();
        this.isLoading = false;
        return;
      }
    }

    this.rows.forEach((r) => {
      const amount = r.amount;
      const quantity = r.quantity;
      const valType = r.type || 'Fixed Amount';

      const hasAmount =
        amount !== undefined &&
        amount !== "" &&
        !isNaN(amount) &&
        (valType === 'Percentage' ? Number(amount) >= 0 && Number(amount) <= 100 : Number(amount) > 0);

      if (hasAmount && (quantity === undefined || quantity === "" || isNaN(quantity))) {
        r.quantity = 1;
      }
    });

    this.rows.forEach((r) => {
      const amount = r.amount;
      const quantity = r.quantity;
      const valType = r.type || 'Fixed Amount';

      const hasAmount =
        amount !== undefined &&
        amount !== "" &&
        !isNaN(amount) &&
        (valType === 'Percentage' ? Number(amount) >= 0 && Number(amount) <= 100 : Number(amount) > 0);
      const hasQuantity =
        quantity !== undefined &&
        quantity !== "" &&
        !isNaN(quantity) &&
        Number(quantity) > 0;

      if ((hasAmount && !hasQuantity) || (!hasAmount && hasQuantity)) {
        this.invalidFields[r.key] = {
          amountError: !hasAmount,
          quantityError: !hasQuantity
        };
        hasValidationError = true;
      }

      if (valType === 'Percentage' && amount !== '' && (!isFinite(amount) || Number(amount) < 0 || Number(amount) > 100)) {
        const existing = this.invalidFields[r.key] || {};
        this.invalidFields[r.key] = { ...existing, amountError: true };
        hasValidationError = true;
      }

      if (r.isDualValue && r.percent !== '' && (!isFinite(r.percent) || Number(r.percent) < 0 || Number(r.percent) > 100)) {
        const existing = this.invalidFields[r.key] || {};
        this.invalidFields[r.key] = { ...existing, percentError: true };
        hasValidationError = true;
      }
    });

    if (hasValidationError) {
      this.message = "Please fix validation errors before saving.";
      this.messageIsError = true;
      this.refreshDisplayRows();
      this.isLoading = false;
      return;
    }

    try {
      const initialByKey = {};
      this.initialRows.forEach((r) => { initialByKey[r.key] = r.amount; });

      this.rows.forEach((r) => {
        const newAmt = r.amount;
        const oldAmt = initialByKey[r.key];
        const hasAmount = newAmt !== undefined && newAmt !== "";
        if (hasAmount) {
          toUpsert[r.key] = newAmt;
          qtyMap[r.key] = r.quantity;
          typeMap[r.key] = r.type;
        }
        if (!hasAmount && oldAmt !== undefined && oldAmt !== "") {
          toDelete.push(r.key);
        }
      });

      if (Object.keys(toUpsert).length > 0) {
        await upsertConditions({
          parentId: this.recordId,
          parentType: this.parentType,
          conditionAmounts: toUpsert,
          conditionQuantities: qtyMap,
          conditionTypes: typeMap
        });
      }

      if (toDelete.length > 0) {
        await deleteConditions({
          parentId: this.recordId,
          parentType: this.parentType,
          conditionTypesToDelete: toDelete
        });
      }

      await this.loadAll();
      this.message = "Conditions updated successfully!";
      this.messageIsError = false;
      this.isEditing = false;

    } catch (e) {
      this.showError(e);
    }
    this.isLoading = false;
  }

  handleCancel() {
    this.isEditing = false;
    this.rows = JSON.parse(JSON.stringify(this.initialRows));
    this.invalidFields = {};
    this.refreshDisplayRows();
    this.message = "";
    this.messageIsError = false;
  }

  showError(e) {
    let msg = e && e.body && e.body.message ? e.body.message : e.message || "Unknown error";
    // eslint-disable-next-line no-console
    console.error("Apex error:", e);
    this.message = "Error: " + msg;
    this.messageIsError = true;
  }

  refresh() {
    this.loadAll();
  }

  _findBasePriceKey() {
    const match = this.conditionTypeOptions.find(
      (opt) => opt.label === 'Base Price' || opt.value === 'Base Price'
    );
    return match ? match.value : null;
  }

  _getBasePriceAmount() {
    const baseRow = this.rows.find((r) => r.label === 'Base Price' || r.key === 'Base Price');
    if (baseRow && baseRow.amount !== '' && !isNaN(baseRow.amount)) {
      return Number(baseRow.amount);
    }
    return null;
  }

  get messageClass() {
    const base = 'slds-notify slds-notify_alert slds-theme_alert-texture slds-m-top_medium';
    return this.messageIsError ? `${base} slds-theme_error` : `${base} slds-theme_info`;
  }

  get messageAssistive() {
    return this.messageIsError ? 'Error' : 'Info';
  }

  // ---------- SUMMARY HELPERS (Amount_By_Type__c) ----------
  _getAmtByType(key) {
    const row = this.rows.find(r => r.key === key || r.label === key);
    const val = row ? row.amountByType : 0;
    return Number.isFinite(val) ? Number(val) : 0;
  }

  _sumAmt(keys) {
    return keys.reduce((acc, k) => acc + this._getAmtByType(k), 0);
  }

  _recomputeSummary() {
    const baseDiscountNet = this._getAmtByType(KEY_BASE_DISCOUNT);
    const baseRaw         = this._getAmtByType(KEY_BASE);
    const hasDiscount     = baseDiscountNet > 0;

    const baseNet = hasDiscount ? baseDiscountNet : baseRaw;

    const otherCharges   = this._sumAmt(OTHER_CHARGE_KEYS);
    const gstConstruction = this._sumAmt([KEY_CGST_CONSTR, KEY_SGST_CONSTR]);
    const gstOther        = this._sumAmt([KEY_CGST_OTHER, KEY_SGST_OTHER]);

    const finalTotal = baseNet + otherCharges + gstConstruction + gstOther;

    this.summary = {
      baseNet,
      hasDiscount,
      otherCharges,
      gstConstruction,
      gstOther,
      finalTotal
    };
  }
}