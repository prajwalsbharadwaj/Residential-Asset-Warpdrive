import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, deleteRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getActions from '@salesforce/apex/WdGlassRecordController.getActions';
import submitForApproval from '@salesforce/apex/WdGlassRecordController.submitForApproval';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { SECTIONS, RECORD_CONFIG } from 'c/wdGlassLayouts';
import { formatDate, formatTime, formatInr, inrParts } from 'c/wdGlassFormat';

const VISIBLE_ACTIONS = 2;
const ADDRESS_ORDER = ['Street', 'City', 'StateCode', 'State', 'PostalCode', 'CountryCode', 'Country'];
const WHO_OBJECTS = new Set(['Lead', 'Contact']);

function errorMessage(error) {
    const body = error?.body;
    if (Array.isArray(body)) {
        return body.map((b) => b.message).join(', ');
    }
    return body?.message || body?.output?.errors?.[0]?.message || error?.message || 'Something went wrong.';
}

export default class WdGlassRecord extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    objectInfo;
    record;
    fieldsToLoad;
    actions = [];
    error;
    editing = false;
    saving = false;
    menuOpen = false;
    collapsed = {};

    // ---------- data ----------

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredInfo({ data, error }) {
        if (data) {
            this.objectInfo = data;
            this.fieldsToLoad = this.buildFieldList(data);
        } else if (error) {
            this.error = errorMessage(error);
        }
    }

    @wire(getRecord, { recordId: '$recordId', optionalFields: '$fieldsToLoad' })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
            this.error = undefined;
        } else if (error) {
            this.error = errorMessage(error);
        }
    }

    @wire(getActions, { objectApiName: '$objectApiName' })
    wiredActions({ data }) {
        if (data) {
            this.actions = data;
        }
    }

    get config() {
        return RECORD_CONFIG[this.objectApiName] || {};
    }

    get sectionDefs() {
        return SECTIONS[this.objectApiName] || [];
    }

    get highlightFields() {
        if (this.config.highlights) {
            return this.config.highlights;
        }
        const nameFields = new Set(this.objectInfo?.nameFields || []);
        const first = this.sectionDefs[0]?.fields || [];
        return first.filter((f) => !nameFields.has(f)).slice(0, 4);
    }

    buildFieldList(info) {
        const obj = this.objectApiName;
        const wanted = new Set(['CreatedDate', 'LastModifiedDate', ...(info.nameFields || [])]);
        this.sectionDefs.forEach((s) => s.fields.forEach((f) => wanted.add(f)));
        this.highlightFields.forEach((f) => wanted.add(f));
        (this.config.facts || []).forEach((f) => wanted.add(f));
        (this.config.alerts || []).forEach((a) => wanted.add(a.field));
        if (this.config.pathField) {
            wanted.add(this.config.pathField);
        }

        const result = new Set();
        wanted.forEach((api) => {
            const fi = info.fields[api];
            if (!fi) {
                return;
            }
            result.add(`${obj}.${api}`);
            if (fi.dataType === 'Reference' && fi.relationshipName) {
                const nameField = fi.referenceToInfos?.[0]?.nameFields?.[0] || 'Name';
                result.add(`${obj}.${fi.relationshipName}.${nameField}`);
            }
            if (fi.compound) {
                Object.values(info.fields)
                    .filter((c) => c.compoundFieldName === api && c.apiName !== api)
                    .forEach((c) => result.add(`${obj}.${c.apiName}`));
            }
        });
        return [...result];
    }

    // ---------- field display ----------

    raw(api) {
        return this.record?.fields?.[api]?.value;
    }

    fieldView(api) {
        const info = this.objectInfo?.fields?.[api];
        if (!info || !this.record) {
            return null;
        }
        const node = this.record.fields[api];
        const value = node?.value;
        const label = info.dataType === 'Reference' ? info.label.replace(/ ID$/, '') : info.label;
        const view = { api, key: api, label, dataType: info.dataType, raw: value, text: '—', empty: true, isRecordLink: false, href: null };
        const set = (text) => {
            if (text !== null && text !== undefined && text !== '') {
                view.text = String(text);
                view.empty = false;
            }
        };

        switch (info.dataType) {
            case 'Reference': {
                const rel = this.record.fields[info.relationshipName];
                const nameField = info.referenceToInfos?.[0]?.nameFields?.[0] || 'Name';
                set(rel?.displayValue || rel?.value?.fields?.[nameField]?.value || value);
                if (value) {
                    view.isRecordLink = true;
                    view.linkId = value;
                }
                break;
            }
            case 'Boolean':
                view.text = value ? 'Yes' : 'No';
                view.empty = false;
                view.isBoolean = true;
                view.boolClass = value ? 'bool bool_on' : 'bool';
                break;
            case 'Currency':
                set(value === null || value === undefined ? null : formatInr(value));
                break;
            case 'Date':
                set(value ? formatDate(value) : null);
                break;
            case 'DateTime':
                set(value ? `${formatDate(value)}, ${formatTime(new Date(value))}` : null);
                break;
            case 'Address': {
                const parts = Object.values(this.objectInfo.fields)
                    .filter((c) => c.compoundFieldName === api && c.apiName !== api && !/Latitude|Longitude|GeocodeAccuracy/.test(c.apiName))
                    .sort((a, b) => this.addressRank(a.apiName) - this.addressRank(b.apiName))
                    .map((c) => this.record.fields[c.apiName]?.displayValue || this.record.fields[c.apiName]?.value)
                    .filter(Boolean);
                set(parts.join(', '));
                break;
            }
            case 'Email':
                set(value);
                view.href = value ? `mailto:${value}` : null;
                break;
            case 'Phone':
                set(value);
                view.href = value ? `tel:${value}` : null;
                break;
            case 'Url':
                set(value);
                view.href = value && !/^https?:\/\//i.test(value) ? `https://${value}` : value;
                break;
            default:
                set(node?.displayValue ?? value);
        }
        view.isHref = !!view.href && !view.empty;
        view.isPlain = !view.isRecordLink && !view.isHref && !view.isBoolean;
        view.valueClass = view.empty ? 'value value_empty' : 'value';
        return view;
    }

    addressRank(apiName) {
        const idx = ADDRESS_ORDER.findIndex((suffix) => apiName.includes(suffix));
        return idx === -1 ? 99 : idx;
    }

    // ---------- hero ----------

    get loaded() {
        return !!(this.record && this.objectInfo);
    }

    get eyebrow() {
        return this.config.eyebrow || this.objectInfo?.label || '';
    }

    get title() {
        if (!this.record) {
            return '';
        }
        const nameApi = this.record.fields.Name ? 'Name' : this.objectInfo?.nameFields?.[0];
        return this.raw(nameApi) || this.fieldView(nameApi)?.text || '';
    }

    get subtitle() {
        if (!this.loaded) {
            return 'Loading…';
        }
        const facts = (this.config.facts || [])
            .map((f) => this.fieldView(f))
            .filter((v) => v && !v.empty)
            .map((v) => v.text);
        const created = this.raw('CreatedDate');
        if (created) {
            facts.push(`created ${formatDate(created)}`);
        }
        const modified = this.raw('LastModifiedDate');
        if (modified) {
            facts.push(`updated ${formatDate(modified)}`);
        }
        return facts.join(' · ');
    }

    get highlights() {
        if (!this.loaded) {
            return [];
        }
        return this.highlightFields
            .map((f) => this.fieldView(f))
            .filter(Boolean)
            .map((v) => {
                let text = v.text;
                if (v.dataType === 'Currency' && !v.empty) {
                    const parts = inrParts(v.raw);
                    text = `${parts.value} ${parts.unit}`.trim();
                }
                return { ...v, text, valueClass: v.empty ? 'hl-value hl-value_empty' : 'hl-value' };
            });
    }

    get hasHighlights() {
        return this.highlights.length > 0;
    }

    get alerts() {
        if (!this.loaded) {
            return [];
        }
        return (this.config.alerts || [])
            .filter((a) => this.record.fields[a.field] && this.raw(a.field) === a.equals)
            .map((a) => ({ key: a.field, message: a.message }));
    }

    get pathField() {
        const f = this.config.pathField;
        return f && this.objectInfo?.fields?.[f] ? f : null;
    }

    get pathFieldRef() {
        return this.pathField ? `${this.objectApiName}.${this.pathField}` : null;
    }

    get pathValue() {
        return this.pathField ? this.raw(this.pathField) : null;
    }

    get recordTypeId() {
        return this.record?.recordTypeId || this.objectInfo?.defaultRecordTypeId;
    }

    /** Accounts get the customer 360 (wdGlassCustomer) instead of generic highlights and related lists. */
    get isCustomer() {
        return !!this.config.customer360;
    }

    get showRelatedLists() {
        return !this.isCustomer;
    }

    get extraLists() {
        return this.config.relatedLists || [];
    }

    get extras() {
        return this.config.extras || {};
    }

    get isWhoRecord() {
        return WHO_OBJECTS.has(this.objectApiName);
    }

    get isLead() {
        return this.objectApiName === 'Lead';
    }

    get isLeadOrContact() {
        return this.objectApiName === 'Lead' || this.objectApiName === 'Contact';
    }

    // ---------- sections ----------

    get sections() {
        if (!this.loaded) {
            return [];
        }
        return this.sectionDefs
            .map((s, i) => {
                const fields = s.fields.map((f) => this.fieldView(f)).filter(Boolean);
                const isCollapsed = !!this.collapsed[s.label];
                return {
                    key: `s${i}`,
                    label: s.label,
                    fields,
                    isCollapsed,
                    isOpen: !isCollapsed,
                    ariaExpanded: String(!isCollapsed),
                    chevronClass: isCollapsed ? 'chevron chevron_closed' : 'chevron',
                    gridClass: s.columns === 1 ? 'fields fields_one' : 'fields',
                    filled: `${fields.filter((f) => !f.empty).length}/${fields.length}`
                };
            })
            .filter((s) => s.fields.length);
    }

    handleToggleSection(event) {
        this.collapsed = { ...this.collapsed, [label]: !this.collapsed[label] };
    }

    // ---------- actions ----------

    get actionItems() {
        const byName = new Map(this.actions.map((a) => [a.apiName, a]));
        let ordered = this.actions;
        if (this.config.actions) {
            ordered = this.config.actions.map((n) => byName.get(n)).filter(Boolean);
        } else if (this.config.primaryActions) {
            const first = this.config.primaryActions.map((n) => byName.get(n)).filter(Boolean);
            ordered = [...first, ...this.actions.filter((a) => !first.includes(a))];
        }
        return ordered.map((a) => ({ key: a.apiName, apiName: a.apiName, label: a.label, type: a.type }));
    }

    get visibleActions() {
        return this.actionItems.slice(0, VISIBLE_ACTIONS);
    }

    get menuActions() {
        return this.actionItems.slice(VISIBLE_ACTIONS);
    }

    get hasMenu() {
        return this.menuActions.length > 0;
    }

    get editLabel() {
        return this.editing ? 'Cancel' : 'Edit';
    }

    toggleMenu() {
        this.menuOpen = !this.menuOpen;
    }

    handleMenuFocusOut(event) {
        if (!this.template.querySelector('.menu')?.contains(event.relatedTarget)) {
            this.menuOpen = false;
        }
    }

    handleMenuKey(event) {
        if (event.key === 'Escape') {
            this.menuOpen = false;
        }
    }

    handleAction(event) {
        const { api } = event.currentTarget.dataset;
        this.menuOpen = false;
        switch (api) {
            case 'Delete':
                this.confirmDelete();
                return;
            case 'Clone':
                this.navigateToRecord('clone');
                return;
            case 'Submit':
                this.submitApproval();
                return;
            case 'Convert':
                this.navigateToUrl(`/lightning/cmp/runtime_sales_lead__convertDesktopConsole?leadConvert__leadId=${this.recordId}`);
                return;
            default:
        }
        this.openQuickAction(api);
    }

    // LEX opens a quick action as a modal over the record when routed through /lightning/action/quick.
    openQuickAction(actionName) {
        const recordPath = `/lightning/r/${this.objectApiName}/${this.recordId}/view`;
        const url =
            `/lightning/action/quick/${encodeURIComponent(actionName)}?objectApiName&context=RECORD_DETAIL` +
            `&recordId=${this.recordId}&backgroundContext=${encodeURIComponent(recordPath)}`;
        this.navigateToUrl(url);
    }

    handleEditToggle() {
        this.editing = !this.editing;
        this.menuOpen = false;
    }

    handleEditRequest() {
        if (!this.editing) {
            this.editing = true;
        }
    }

    handleSubmit() {
        this.saving = true;
    }

    handleSaved() {
        this.saving = false;
        this.editing = false;
        this.toast('Saved', `${this.title || 'Record'} was updated.`, 'success');
    }

    handleSaveError() {
        this.saving = false;
    }

    async submitApproval() {
        const ok = await LightningConfirm.open({
            message: `Submit ${this.title} for approval?`,
            label: 'Submit for Approval',
            theme: 'info'
        });
        if (!ok) {
            return;
        }
        try {
            const status = await submitForApproval({ recordId: this.recordId, comments: null });
            this.toast('Submitted', `Approval status: ${status}.`, 'success');
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (e) {
            this.toast('Could not submit', errorMessage(e), 'error');
        }
    }

    async confirmDelete() {
        const ok = await LightningConfirm.open({
            message: `Delete ${this.title}? This moves the record to the Recycle Bin.`,
            label: `Delete ${this.objectInfo?.label || 'record'}`,
            theme: 'warning'
        });
        if (!ok) {
            return;
        }
        try {
            await deleteRecord(this.recordId);
            this.toast('Deleted', `${this.title} was deleted.`, 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: this.objectApiName, actionName: 'home' }
            });
        } catch (e) {
            this.toast('Could not delete', errorMessage(e), 'error');
        }
    }

    handleOpenRecord(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }

    navigateToRecord(actionName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: this.objectApiName, actionName }
        });
    }

    navigateToUrl(url) {
        this[NavigationMixin.Navigate]({ type: 'standard__webPage', attributes: { url } });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}