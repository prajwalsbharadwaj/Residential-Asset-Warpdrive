# Object Schema Specification Template

> **Instructions for Author / AI Agent**: Use this template to document the technical specification of any new or modified Salesforce SObject before generating metadata or code.

---

# SObject: `[Custom_Object_API_Name__c]`

## 1. Object Metadata Overview
- **Label**: `[Singular Label]` (e.g., Booking)
- **Plural Label**: `[Plural Label]` (e.g., Bookings)
- **API Name**: `[Object_API_Name__c]`
- **Description**: [Concise business description of what this entity represents]
- **Sharing Model**: `Private` | `Read/Write` | `ControlledByParent`
- **Track History**: `Yes` | `No`
- **Enable Reports / Search / Activities**: `Yes` / `No`

---

## 2. Entity Relationships

### Parent Relationships (Incoming Lookups / Master-Details)
| Relationship Field API Name | Parent Object | Type (Master-Detail / Lookup) | Cascade Delete? | Child Relationship Name |
| :--- | :--- | :--- | :--- | :--- |
| `Parent_Record__c` | `Parent_Object__c` | Master-Detail | Yes | `Child_Records` |
| `Customer__c` | `Account` | Lookup (Required) | No (Don't allow delete) | `Customer_Bookings` |

### Child Related Lists (Outgoing)
| Child SObject | Child Lookup Field | Relationship Label |
| :--- | :--- | :--- |
| `Installment__c` | `Booking__c` | Installment Schedules |
| `Booking_Applicant__c` | `Booking__c` | Booking Applicants |

---

## 3. Data Dictionary & Field Catalog

| Field Label | API Name | Data Type | Req? | Index? | Default Value | Description & Business Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Booking Number** | `Name` | Auto-Number | Yes | Auto | `BKG-{0000}` | System unique identifier. |
| **Status** | `Status__c` | Picklist | Yes | Yes | `Draft` | Lifecycle state: Draft, Active, Sold, Cancelled. |
| **Total Amount** | `Total_Amount__c` | Currency(16, 2) | Yes | No | 0.00 | Total commercial agreement value. |
| **External ERP ID** | `SAP_Contract_Code__c` | Text(50) | No | Ext ID | - | Authoritative contract ID synced from SAP S/4HANA. |
| **Active?** | `Is_Active__c` | Checkbox | No | No | `true` | Soft-deletion or active state flag. |

---

## 4. Formula & Roll-Up Summary Fields

### Roll-Up Summaries
- **`Total_Paid_Amount__c`**:
  - *Summary Type*: `SUM`
  - *Summarized Object*: `Installment__c`
  - *Field*: `Paid_Amount__c`
  - *Filter*: `Status__c = 'Paid'`

### Formulas
- **`Outstanding_Balance__c`**:
  - *Formula Return Type*: `Currency`
  - *Formula Expression*:
    ```
    Total_Booking_Amount__c - Total_Paid_Amount__c
    ```

---

## 5. Validation Rules

### VR-01: `Enforce_Mandatory_Customer_PAN`
- **Active**: `true`
- **Error Condition Formula**:
  ```
  AND(
      ISPICKVAL(Status__c, 'Confirmed'),
      ISBLANK(Customer_PAN__c)
  )
  ```
- **Error Message**: *"Statutory compliance: Customer PAN is required before confirming a booking."*
- **Error Location**: `Customer_PAN__c`

---

## 6. Record Types & Business Processes
*(If applicable)*

| Record Type Name | Developer Name | Description | Active | Picklist Variations |
| :--- | :--- | :--- | :--- | :--- |
| **Residential** | `Residential` | Standard apartment unit | Yes | Status values: New, Under Review, Sold |
| **Commercial** | `Commercial` | Retail/Office spaces | Yes | Status values: Enquiry, Leasing, Leased |

---

## 7. Security & Persona Permissions Matrix

| Profile / Permission Set | Read | Create | Edit | Delete | View All | Modify All | FLS Restrictions |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| `Sales_Executive` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | Read-Only on `Total_Paid_Amount__c` |
| `Finance_Controller` | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | Full Edit on all financial fields |
| `System_Administrator`| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | None |
