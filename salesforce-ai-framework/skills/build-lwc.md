# Skill: Building Enterprise Lightning Web Components (LWC)

## Purpose
This skill provides a standardized, rapid-engineering workflow for AI agents and Salesforce developers to design, develop, test, and deploy production-ready Lightning Web Components (LWC) that adhere to high design aesthetics and enterprise state management standards.

---

## 1. Component Anatomy & File Structure
Every enterprise LWC bundle must follow this canonical 4-file structure:

```
force-app/main/default/lwc/myEnterpriseComponent/
├── myEnterpriseComponent.html           # Declarative template with SLDS & semantic markup
├── myEnterpriseComponent.js             # Reactive controller, wire adapters & event handlers
├── myEnterpriseComponent.css            # Scoped design system styles (WarpDrive palette)
├── myEnterpriseComponent.js-meta.xml    # Target configs, exposed surfaces & property definitions
└── __tests__/                           # Jest unit test suite
    └── myEnterpriseComponent.test.js
```

---

## 2. Step-by-Step LWC Engineering Workflow

```
[1. Wireframe & State Architecture]
       │
       ▼
[2. Metadata Configuration (.js-meta.xml)]
       │
       ▼
[3. Scoped CSS & WarpDrive Design System]
       │
       ▼
[4. HTML Template Structure & Directives]
       │
       ▼
[5. JavaScript Controller & Wire / Apex Binding]
       │
       ▼
[6. Toast Feedback & Error Handling]
       │
       ▼
[7. Deployment & Verification]
```

### Step 1: Wireframe & State Architecture
- Deconstruct the UI into:
  1. **Header Card**: Title, icon, status badge, primary action buttons.
  2. **Filter / Control Bar**: Dropdowns, search inputs, active tags.
  3. **Data Display Grid**: Table, card tiles, or timeline view.
  4. **Action Drawer / Modal**: Guided entry forms or approval dialogues.
- Define internal state variables (`isLoading`, `records`, `selectedRecordId`, `errorMessage`).

### Step 2: Metadata Configuration (`.js-meta.xml`)
Configure target surfaces with explicit page contexts:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>60.0</apiVersion>
    <isExposed>true</isExposed>
    <masterLabel>Residential Inventory Explorer</masterLabel>
    <description>Interactive visual floor plate and unit booking component.</description>
    <targets>
        <target>lightning__RecordPage</target>
        <target>lightning__AppPage</target>
        <target>lightning__HomePage</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__RecordPage">
            <objects>
                <object>Project__c</object>
                <object>Tower__c</object>
                <object>Opportunity</object>
            </objects>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

### Step 3: Implement Scoped CSS (WarpDrive Design System)

> [!IMPORTANT]
> **Strict Light Theme**: Always apply `#FFFFFF` surfaces, `#00A859` emerald green highlights, `#ECFDF5` mint accents, and pill buttons (`border-radius: 9999px`).

```css
/* Card Container */
.wd-card {
    background-color: #FFFFFF;
    border: 1px solid #E2E8F0;
    border-radius: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.03);
    padding: 1.25rem;
    transition: box-shadow 0.2s ease;
}

/* Header & Typography */
.wd-title {
    font-size: 1.15rem;
    font-weight: 700;
    color: #0F172A;
    letter-spacing: -0.01em;
}

/* Pill Action Button */
.wd-pill-button {
    background-color: #00A859;
    color: #FFFFFF;
    border-radius: 9999px;
    padding: 0.5rem 1.25rem;
    font-size: 0.875rem;
    font-weight: 600;
    border: none;
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(0, 168, 89, 0.3);
    transition: all 0.2s ease-in-out;
}
.wd-pill-button:hover {
    background-color: #008C4A;
    transform: translateY(-1px);
    box-shadow: 0 6px 16px rgba(0, 168, 89, 0.4);
}

/* Status / Mint Badges */
.wd-badge-available {
    background-color: #ECFDF5;
    color: #065F46;
    border: 1px solid #A7F3D0;
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
}
```

### Step 4: HTML Template Structure
Use modern `lwc:if` directives, semantic headings, and descriptive labels:
```html
<template>
    <div class="wd-card">
        <!-- Spinner Overlay -->
        <template lwc:if={isLoading}>
            <lightning-spinner alternative-text="Loading inventory data" size="medium"></lightning-spinner>
        </template>

        <!-- Header -->
        <div class="slds-grid slds-grid_vertical-align-center slds-m-bottom_medium">
            <div class="slds-col">
                <h2 class="wd-title">{projectTitle}</h2>
                <p class="slds-text-body_small slds-text-color_weak">{subHeader}</p>
            </div>
            <div class="slds-col slds-grow-0">
                <button class="wd-pill-button" onclick={handleNewBooking} disabled={isSubmitDisabled}>
                    Book Tagged Unit
                </button>
            </div>
        </div>

        <!-- Zero State Guard -->
        <template lwc:if={hasNoUnits}>
            <div class="slds-text-align_center slds-p-around_large slds-text-color_weak">
                No units match your selected filter criteria.
            </div>
        </template>
    </div>
</template>
```

### Step 5: JavaScript Controller & Wire / Apex Binding
```javascript
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getUnitsByFloor from '@salesforce/apex/InventoryExplorerController.getUnitsByFloor';
import bookUnitImperative from '@salesforce/apex/InventoryExplorerController.bookUnit';

export default class InventoryExplorer extends LightningElement {
    @api recordId; // Project or Tower ID
    @track selectedUnitId;
    isLoading = false;
    wiredUnitsResult;
    units = [];

    @wire(getUnitsByFloor, { floorId: '$selectedFloorId' })
    wiredUnits(result) {
        this.wiredUnitsResult = result;
        if (result.data) {
            this.units = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', result.error.body?.message || 'Error loading units', 'error');
            this.isLoading = false;
        }
    }

    async handleNewBooking() {
        this.isLoading = true;
        try {
            await bookUnitImperative({ unitId: this.selectedUnitId });
            this.showToast('Success', 'Unit booked successfully', 'success');
            await refreshApex(this.wiredUnitsResult);
        } catch (error) {
            this.showToast('Booking Failed', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
```

---

## 3. Deployment & Local Verification Checklist
- [ ] Run linter: `npm run lint` or check ESLint rules.
- [ ] Deploy to target sandbox/scratch org:
  ```bash
  sf project deploy start --source-dir force-app/main/default/lwc/myEnterpriseComponent --target-org <alias>
  ```
- [ ] Verify light-mode presentation on desktop and tablet viewports.
- [ ] Confirm `@api recordId` reactivity when placed on Record Pages.
