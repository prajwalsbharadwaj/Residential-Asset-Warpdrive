# Salesforce AI Framework — Lightning Web Components (LWC) Rules

## 1. Architectural Philosophy
Lightning Web Components (LWC) in this framework must adhere to standard web components specifications, enterprise state management, and modern component composition.

```
┌────────────────────────────────────────────────────────┐
│ Smart / Container Component (e.g. inventoryExplorer)  │
│  - State management, data fetching, LMS subscription   │
│  - Orchestrates events and passes data downward        │
└───────────────┬────────────────────────┬───────────────┘
                │ Properties (@api)      │ Events (CustomEvent)
                ▼                        ▲
┌───────────────────────────────┐ ┌──────────────────────┐
│ Presentational Component      │ │ Interactive Widget   │
│ (e.g. unitCard)               │ │ (e.g. priceCalculator│
│  - Pure UI, zero direct Apex  │ │  - Local user input  │
│  - Emits events on click/hover│ │  - Emits change evts │
└───────────────────────────────┘ └──────────────────────┘
```

### Key Principles
1. **Container vs. Presenter Pattern**:
   - High-level containers fetch data via `@wire` or Apex and handle business logic.
   - Low-level leaf components accept data via `@api` properties and dispatch `CustomEvent`s upward. Leaf components must never call Apex directly.
2. **Single Responsibility**:
   - Each component must have one clearly defined responsibility. If an LWC exceeds 250-300 lines of JavaScript or HTML, decompose it into sub-components.

---

## 2. Reactivity & State Management
1. **Use Primitive & Object Reactivity Appropriately**:
   - Primitive variables (`String`, `Boolean`, `Number`) are automatically reactive.
   - For complex nested objects or arrays where individual properties mutate, use `@track` or clone the reference:
     ```javascript
     // Preferred immutable update pattern
     this.selectedUnits = [...this.selectedUnits, newUnit];
     this.bookingData = { ...this.bookingData, status: 'Confirmed' };
     ```
2. **Public Properties (`@api`)**:
   - Treat `@api` properties as **read-only** from within the child component. Never mutate `@api` properties directly; emit a `CustomEvent` to notify the parent to update the source of truth.
   - Provide getter and setter pairs when side effects (such as data normalization or recalculation) must trigger on property change.
3. **Getters for Derived State**:
   - Compute formatted currencies, disabled states, or conditional classes using getters rather than embedding logic inside HTML templates.
     ```javascript
     get isSubmitDisabled() {
         return !this.selectedUnitId || this.isProcessing || this.hasErrors;
     }

     get formattedTotalPrice() {
         return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(this.totalPrice || 0);
     }
     ```

---

## 3. Data Ingestion: Wire Service vs. Imperative Apex

| Feature | `@wire` (Reactive Wire) | Imperative Apex (`callApex()`) |
| :--- | :--- | :--- |
| **Best Used For** | Read-only queries, page load data, reactive filters | DML operations, transactional updates, button clicks |
| **Caching** | Client-side cached (`cacheable=true`) | Uncached, real-time |
| **Refresh** | Requires `refreshApex(this.wiredResult)` | Direct promise chain (`async/await`) |
| **Execution** | Automatic when dynamic `$parameter` changes | Explicit user or programmatic trigger |

### Code Standard for Wire Ingestion
Always store the provisioned wire object to enable `refreshApex`:
```javascript
wiredUnitsResult;

@wire(getUnitsByFloor, { floorId: '$selectedFloorId' })
wiredUnits(result) {
    this.wiredUnitsResult = result;
    const { data, error } = result;
    if (data) {
        this.units = data;
        this.errorMessage = undefined;
    } else if (error) {
        this.errorMessage = this.reduceErrors(error);
        this.units = [];
    }
}
```

### Cache Invalidation Standards
When an imperative DML call updates data displayed by a wired component, invalidate the client cache using:
- `refreshApex(this.wiredUnitsResult)` for custom Apex wire adapters.
- `getRecordNotifyChange([{ recordId: this.recordId }])` from `lightning/uiRecordApi` for Lightning Data Service cache updates.

---

## 4. Cross-Component Communication
1. **Parent-to-Child**: Pass data down using `@api` properties and invoke `@api` exposed methods when imperative commands are necessary.
2. **Child-to-Parent**: Dispatch standard `CustomEvent` with payload in `detail`:
   ```javascript
   this.dispatchEvent(new CustomEvent('unitselect', {
       detail: { unitId: this.unit.Id, configuration: this.unit.Configuration__c },
       bubbles: false,
       composed: false
   }));
   ```
3. **Unrelated / Cross-DOM Components**:
   - Use **Lightning Message Service (LMS)** with a `.messageChannel-meta.xml` channel.
   - Always unsubscribe and clean up subscriptions inside `disconnectedCallback()` to avoid memory leaks.

---

## 5. UI/UX & SLDS Aesthetics (WarpDrive Standards)

> [!IMPORTANT]
> **Strict Light-Mode Mandate**: All components must present a pristine, light-theme interface. Never introduce dark slate, navy, or pitch-black container backgrounds.

### Color Tokens & Styling Rules
1. **Primary Palette**:
   - Primary Emerald Accent: `#00A859`
   - Primary Hover: `#008C4A`
   - Mint Soft Background: `#ECFDF5` or `#E6F7EF`
   - Mint Accent Border: `#A7F3D0`
   - Deep Forest Text on Mint: `#065F46` or `#047857`
   - Dark Headings / Text: `#0F172A`
   - Secondary / Muted Text: `#64748B`
   - Card Background: `#FFFFFF`
   - Page Canvas: `#F8FAFC`
2. **Button Shapes**:
   - All primary action buttons must be styled as **pills** (`border-radius: 9999px`) with subtle elevation:
     ```css
     .custom-pill-btn {
         background-color: #00A859;
         color: #FFFFFF;
         border-radius: 9999px;
         padding: 0.5rem 1.25rem;
         font-weight: 600;
         border: none;
         box-shadow: 0 4px 14px rgba(0, 168, 89, 0.35);
         transition: all 0.2s ease;
     }
     .custom-pill-btn:hover {
         background-color: #008C4A;
         transform: translateY(-1px);
     }
     ```
3. **Numbered Step Badges**:
   - Multi-step wizards and timeline indicators must use circular badges (`01`, `02`, `04`) with emerald fills or mint borders.

---

## 6. Lifecycle Hooks & Performance Guidelines
1. **`connectedCallback()`**:
   - Use for initializing component state, subscribing to LMS, or reading URL parameters.
   - Avoid performing direct DOM manipulation because child nodes may not yet be rendered.
2. **`renderedCallback()`**:
   - If DOM manipulation or third-party library initialization is needed, **guard it with a boolean flag** to prevent infinite re-rendering loops:
     ```javascript
     isRendered = false;
     renderedCallback() {
         if (this.isRendered) return;
         this.isRendered = true;
         // Perform one-time setup
     }
     ```
3. **`disconnectedCallback()`**:
   - Unsubscribe from all LMS channels, disconnect ResizeObservers, and remove window event listeners.
4. **Template Directives**:
   - Use `lwc:if`, `lwc:elseif`, and `lwc:else` instead of deprecated `if:true` / `if:false`.
   - In lists (`for:each`), always provide a unique, primitive `key` (e.g. `unit.Id`).

---

## 7. Error Handling, Empty States & Accessibility
1. **Inline Toast Feedback**:
   - Dispatch `ShowToastEvent` from `lightning/platformShowToastEvent` for asynchronous success or critical errors.
2. **Zero-Empty-Canvas Rule**:
   - Never display a blank white box when zero records exist or while data loads.
   - Always display:
     - A `<lightning-spinner>` or custom skeleton card while loading.
     - A formatted empty state illustration or helpful message (e.g., *"No units match the selected 3 BHK filter"*) with an option to reset filters.
3. **Accessibility (a11y)**:
   - Ensure all interactive elements have descriptive `aria-label` or `title` attributes.
   - Verify keyboard navigability (TAB, ENTER, SPACE) for custom action items.
