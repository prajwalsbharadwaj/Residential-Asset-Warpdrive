# scripts/scaffold_metadata.ps1
# Generates all source-format metadata for Residential Real Estate CRM Demo

$baseDir = "force-app/main/default"

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Write-Utf8File($path, $content) {
    $parent = Split-Path $path
    Ensure-Dir $parent
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
}

# -------------------------------------------------------------
# 1. HELPER XML TEMPLATES
# -------------------------------------------------------------
function New-ObjectXml($label, $plural, $sharingModel, $nameFieldLabel, $nameFieldType = "Text", $autoNumberFormat = "") {
    $nameFieldXml = ""
    if ($nameFieldType -eq "AutoNumber") {
        $nameFieldXml = @"
    <nameField>
        <displayFormat>$autoNumberFormat</displayFormat>
        <label>$nameFieldLabel</label>
        <type>AutoNumber</type>
    </nameField>
"@
    } else {
        $nameFieldXml = @"
    <nameField>
        <label>$nameFieldLabel</label>
        <type>Text</type>
    </nameField>
"@
    }

    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <actionOverrides>
        <actionName>Accept</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>CancelEdit</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>Clone</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>Delete</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>Edit</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>List</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>New</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>SaveEdit</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>Tab</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>View</actionName>
        <type>Default</type>
    </actionOverrides>
    <allowInChatterGroups>false</allowInChatterGroups>
    <compactLayoutAssignment>SYSTEM</compactLayoutAssignment>
    <deploymentStatus>Deployed</deploymentStatus>
    <enableActivities>true</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>true</enableHistory>
    <enableLicensing>false</enableLicensing>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <label>$label</label>
$nameFieldXml
    <pluralLabel>$plural</pluralLabel>
    <sharingModel>$sharingModel</sharingModel>
    <visibility>Public</visibility>
</CustomObject>
"@
}

function New-TextField($label, $length = 255, $required = $false, $externalId = $false, $unique = $false) {
    $reqStr = if ($required) { "true" } else { "false" }
    $extStr = if ($externalId) { "true" } else { "false" }
    $uniStr = if ($unique) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>$extStr</externalId>
    <label>$label</label>
    <length>$length</length>
    <required>$reqStr</required>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Text</type>
    <unique>$uniStr</unique>
</CustomField>
"@
}

function New-TextAreaField($label, $required = $false) {
    $reqStr = if ($required) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <required>$reqStr</required>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>TextArea</type>
</CustomField>
"@
}

function New-LongTextAreaField($label, $length = 32768, $visibleLines = 3) {
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <length>$length</length>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>LongTextArea</type>
    <visibleLines>$visibleLines</visibleLines>
</CustomField>
"@
}

function New-NumberField($label, $precision = 18, $scale = 0, $required = $false) {
    $reqStr = if ($required) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <precision>$precision</precision>
    <required>$reqStr</required>
    <scale>$scale</scale>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Number</type>
    <unique>false</unique>
</CustomField>
"@
}

function New-CurrencyField($label, $precision = 18, $scale = 2, $required = $false) {
    $reqStr = if ($required) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <precision>$precision</precision>
    <required>$reqStr</required>
    <scale>$scale</scale>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Currency</type>
</CustomField>
"@
}

function New-PercentField($label, $precision = 5, $scale = 2, $required = $false) {
    $reqStr = if ($required) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <precision>$precision</precision>
    <required>$reqStr</required>
    <scale>$scale</scale>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Percent</type>
</CustomField>
"@
}

function New-DateField($label, $required = $false) {
    $reqStr = if ($required) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <required>$reqStr</required>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Date</type>
</CustomField>
"@
}

function New-DateTimeField($label, $required = $false) {
    $reqStr = if ($required) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <required>$reqStr</required>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>DateTime</type>
</CustomField>
"@
}

function New-CheckboxField($label, $defaultValue = $false) {
    $defStr = if ($defaultValue) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <defaultValue>$defStr</defaultValue>
    <externalId>false</externalId>
    <label>$label</label>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Checkbox</type>
</CustomField>
"@
}

function New-PicklistField($label, [string[]]$values, $required = $false) {
    $reqStr = if ($required) { "true" } else { "false" }
    $valsXml = ($values | ForEach-Object {
        @"
            <value>
                <fullName>$_</fullName>
                <default>false</default>
                <label>$_</label>
            </value>
"@
    }) -join "`n"

    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <required>$reqStr</required>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Picklist</type>
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
$valsXml
        </valueSetDefinition>
    </valueSet>
</CustomField>
"@
}

function New-LookupField($label, $referenceTo, $relationshipLabel, $relationshipName, $required = $false, $deleteConstraint = "SetNull") {
    $reqStr = if ($required) { "true" } else { "false" }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <deleteConstraint>$deleteConstraint</deleteConstraint>
    <externalId>false</externalId>
    <label>$label</label>
    <referenceTo>$referenceTo</referenceTo>
    <relationshipLabel>$relationshipLabel</relationshipLabel>
    <relationshipName>$relationshipName</relationshipName>
    <required>$reqStr</required>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Lookup</type>
</CustomField>
"@
}

function New-MasterDetailField($label, $referenceTo, $relationshipLabel, $relationshipName) {
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <referenceTo>$referenceTo</referenceTo>
    <relationshipLabel>$relationshipLabel</relationshipLabel>
    <relationshipName>$relationshipName</relationshipName>
    <relationshipOrder>0</relationshipOrder>
    <reparentableMasterDetail>false</reparentableMasterDetail>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>MasterDetail</type>
    <writeRequiresMasterRead>false</writeRequiresMasterRead>
</CustomField>
"@
}

function New-FormulaCurrencyField($label, $formula, $precision = 18, $scale = 2) {
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$label</fullName>
    <externalId>false</externalId>
    <formula>$formula</formula>
    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>
    <label>$label</label>
    <precision>$precision</precision>
    <scale>$scale</scale>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Currency</type>
</CustomField>
"@
}

function New-TabXml($customObject, $motif = "Custom63: Chip") {
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomTab xmlns="http://soap.sforce.com/2006/04/metadata">
    <customObject>true</customObject>
    <motif>$motif</motif>
</CustomTab>
"@
}

Write-Host "Creating Custom Objects and Fields..."

# 1. Project__c
Write-Utf8File "$baseDir/objects/Project__c/Project__c.object-meta.xml" (New-ObjectXml "Project" "Projects" "ReadWrite" "Project Name")
Write-Utf8File "$baseDir/objects/Project__c/fields/Location__c.field-meta.xml" (New-TextField "Location__c" 255)
Write-Utf8File "$baseDir/objects/Project__c/fields/Status__c.field-meta.xml" (New-PicklistField "Status__c" @("Planning", "Under Construction", "Ready to Move", "Completed"))
Write-Utf8File "$baseDir/objects/Project__c/fields/RERA_Registration_Number__c.field-meta.xml" (New-TextField "RERA_Registration_Number__c" 50)
Write-Utf8File "$baseDir/objects/Project__c/fields/Total_Towers__c.field-meta.xml" (New-NumberField "Total_Towers__c" 4 0)
Write-Utf8File "$baseDir/objects/Project__c/fields/Description__c.field-meta.xml" (New-LongTextAreaField "Description__c")
Write-Utf8File "$baseDir/tabs/Project__c.tab-meta.xml" (New-TabXml "Project__c" "Custom24: Building")

# 2. Tower__c
Write-Utf8File "$baseDir/objects/Tower__c/Tower__c.object-meta.xml" (New-ObjectXml "Tower" "Towers" "ControlledByParent" "Tower Name")
Write-Utf8File "$baseDir/objects/Tower__c/fields/Project__c.field-meta.xml" (New-MasterDetailField "Project__c" "Project__c" "Towers" "Towers")
Write-Utf8File "$baseDir/objects/Tower__c/fields/Total_Floors__c.field-meta.xml" (New-NumberField "Total_Floors__c" 3 0)
Write-Utf8File "$baseDir/objects/Tower__c/fields/Construction_Status__c.field-meta.xml" (New-PicklistField "Construction_Status__c" @("Excavation", "Plinth", "Superstructure", "Finishing", "Ready for Handover"))
Write-Utf8File "$baseDir/tabs/Tower__c.tab-meta.xml" (New-TabXml "Tower__c" "Custom19: Wrench")

# 3. Floor__c
Write-Utf8File "$baseDir/objects/Floor__c/Floor__c.object-meta.xml" (New-ObjectXml "Floor" "Floors" "ControlledByParent" "Floor Name")
Write-Utf8File "$baseDir/objects/Floor__c/fields/Tower__c.field-meta.xml" (New-MasterDetailField "Tower__c" "Tower__c" "Floors" "Floors")
Write-Utf8File "$baseDir/objects/Floor__c/fields/Floor_Number__c.field-meta.xml" (New-NumberField "Floor_Number__c" 3 0)
Write-Utf8File "$baseDir/objects/Floor__c/fields/Units_Per_Floor__c.field-meta.xml" (New-NumberField "Units_Per_Floor__c" 3 0)
Write-Utf8File "$baseDir/tabs/Floor__c.tab-meta.xml" (New-TabXml "Floor__c" "Custom33: Desk")

# 4. Unit__c
Write-Utf8File "$baseDir/objects/Unit__c/Unit__c.object-meta.xml" (New-ObjectXml "Unit" "Units" "ControlledByParent" "Unit Number")
Write-Utf8File "$baseDir/objects/Unit__c/fields/Floor__c.field-meta.xml" (New-MasterDetailField "Floor__c" "Floor__c" "Units" "Units")
Write-Utf8File "$baseDir/objects/Unit__c/fields/Configuration__c.field-meta.xml" (New-PicklistField "Configuration__c" @("1 BHK", "2 BHK", "2.5 BHK", "3 BHK", "4 BHK", "Penthouse"))
Write-Utf8File "$baseDir/objects/Unit__c/fields/Carpet_Area_SqFt__c.field-meta.xml" (New-NumberField "Carpet_Area_SqFt__c" 8 2)
Write-Utf8File "$baseDir/objects/Unit__c/fields/Super_Built_Up_Area_SqFt__c.field-meta.xml" (New-NumberField "Super_Built_Up_Area_SqFt__c" 8 2)
Write-Utf8File "$baseDir/objects/Unit__c/fields/Base_Price__c.field-meta.xml" (New-CurrencyField "Base_Price__c" 18 2)
Write-Utf8File "$baseDir/objects/Unit__c/fields/Total_Price__c.field-meta.xml" (New-CurrencyField "Total_Price__c" 18 2)
Write-Utf8File "$baseDir/objects/Unit__c/fields/Status__c.field-meta.xml" (New-PicklistField "Status__c" @("Available", "Hold", "Blocked", "Sold"))
Write-Utf8File "$baseDir/objects/Unit__c/fields/SAP_Material_Code__c.field-meta.xml" (New-TextField "SAP_Material_Code__c" 50 $false $true $true)
Write-Utf8File "$baseDir/tabs/Unit__c.tab-meta.xml" (New-TabXml "Unit__c" "Custom63: Chip")

# 5. Site_Visit__c
Write-Utf8File "$baseDir/objects/Site_Visit__c/Site_Visit__c.object-meta.xml" (New-ObjectXml "Site Visit" "Site Visits" "ReadWrite" "Site Visit Number" "AutoNumber" "SV-{00000}")
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Lead__c.field-meta.xml" (New-LookupField "Lead__c" "Lead" "Site Visits" "Site_Visits")
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Opportunity__c.field-meta.xml" (New-LookupField "Opportunity__c" "Opportunity" "Site Visits" "Site_Visits")
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Customer__c.field-meta.xml" (New-LookupField "Customer__c" "Account" "Site Visits" "Site_Visits")
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Project__c.field-meta.xml" (New-LookupField "Project__c" "Project__c" "Site Visits" "Site_Visits")
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Visit_Date_Time__c.field-meta.xml" (New-DateTimeField "Visit_Date_Time__c")
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Status__c.field-meta.xml" (New-PicklistField "Status__c" @("Scheduled", "Conducted", "Cancelled", "No Show"))
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Rating__c.field-meta.xml" (New-PicklistField "Rating__c" @("Hot", "Warm", "Cold"))
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Feedback__c.field-meta.xml" (New-LongTextAreaField "Feedback__c")
Write-Utf8File "$baseDir/objects/Site_Visit__c/fields/Sales_Executive__c.field-meta.xml" (New-LookupField "Sales_Executive__c" "User" "Assigned Site Visits" "Assigned_Site_Visits")
Write-Utf8File "$baseDir/tabs/Site_Visit__c.tab-meta.xml" (New-TabXml "Site_Visit__c" "Custom51: Calendar")

# 6. Payment_Plan__c
Write-Utf8File "$baseDir/objects/Payment_Plan__c/Payment_Plan__c.object-meta.xml" (New-ObjectXml "Payment Plan" "Payment Plans" "ReadWrite" "Payment Plan Name")
Write-Utf8File "$baseDir/objects/Payment_Plan__c/fields/Project__c.field-meta.xml" (New-LookupField "Project__c" "Project__c" "Payment Plans" "Payment_Plans")
Write-Utf8File "$baseDir/objects/Payment_Plan__c/fields/Plan_Type__c.field-meta.xml" (New-PicklistField "Plan_Type__c" @("Construction Linked Plan (CLP)", "Down Payment Plan", "Time Linked Plan"))
Write-Utf8File "$baseDir/objects/Payment_Plan__c/fields/Active__c.field-meta.xml" (New-CheckboxField "Active__c" $true)
Write-Utf8File "$baseDir/objects/Payment_Plan__c/fields/Description__c.field-meta.xml" (New-TextAreaField "Description__c")
Write-Utf8File "$baseDir/tabs/Payment_Plan__c.tab-meta.xml" (New-TabXml "Payment_Plan__c" "Custom40: Compass")

# 7. Payment_Milestone__c
Write-Utf8File "$baseDir/objects/Payment_Milestone__c/Payment_Milestone__c.object-meta.xml" (New-ObjectXml "Payment Milestone" "Payment Milestones" "ControlledByParent" "Milestone Name")
Write-Utf8File "$baseDir/objects/Payment_Milestone__c/fields/Payment_Plan__c.field-meta.xml" (New-MasterDetailField "Payment_Plan__c" "Payment_Plan__c" "Payment Milestones" "Payment_Milestones")
Write-Utf8File "$baseDir/objects/Payment_Milestone__c/fields/Milestone_Percentage__c.field-meta.xml" (New-PercentField "Milestone_Percentage__c" 5 2)
Write-Utf8File "$baseDir/objects/Payment_Milestone__c/fields/Milestone_Order__c.field-meta.xml" (New-NumberField "Milestone_Order__c" 3 0)
Write-Utf8File "$baseDir/objects/Payment_Milestone__c/fields/Trigger_Event__c.field-meta.xml" (New-PicklistField "Trigger_Event__c" @("Booking Token", "Agreement Execution", "Foundation", "5th Floor Slab", "Superstructure", "Possession"))
Write-Utf8File "$baseDir/objects/Payment_Milestone__c/fields/Days_From_Booking__c.field-meta.xml" (New-NumberField "Days_From_Booking__c" 4 0)
Write-Utf8File "$baseDir/tabs/Payment_Milestone__c.tab-meta.xml" (New-TabXml "Payment_Milestone__c" "Custom58: Caduceus")

# 8. Booking__c
Write-Utf8File "$baseDir/objects/Booking__c/Booking__c.object-meta.xml" (New-ObjectXml "Booking" "Bookings" "ReadWrite" "Booking Reference" "AutoNumber" "BKG-{0000}")
Write-Utf8File "$baseDir/objects/Booking__c/fields/Opportunity__c.field-meta.xml" (New-LookupField "Opportunity__c" "Opportunity" "Bookings" "Bookings")
Write-Utf8File "$baseDir/objects/Booking__c/fields/Customer__c.field-meta.xml" (New-LookupField "Customer__c" "Account" "Bookings" "Bookings")
Write-Utf8File "$baseDir/objects/Booking__c/fields/Unit__c.field-meta.xml" (New-LookupField "Unit__c" "Unit__c" "Bookings" "Bookings")
Write-Utf8File "$baseDir/objects/Booking__c/fields/Payment_Plan__c.field-meta.xml" (New-LookupField "Payment_Plan__c" "Payment_Plan__c" "Bookings" "Bookings")
Write-Utf8File "$baseDir/objects/Booking__c/fields/Booking_Date__c.field-meta.xml" (New-DateField "Booking_Date__c")
Write-Utf8File "$baseDir/objects/Booking__c/fields/Total_Booking_Amount__c.field-meta.xml" (New-CurrencyField "Total_Booking_Amount__c" 18 2)
Write-Utf8File "$baseDir/objects/Booking__c/fields/Status__c.field-meta.xml" (New-PicklistField "Status__c" @("New", "KYC in Progress", "Approved", "Active", "Closed", "Cancelled"))
Write-Utf8File "$baseDir/objects/Booking__c/fields/SAP_Customer_Code__c.field-meta.xml" (New-TextField "SAP_Customer_Code__c" 50)
Write-Utf8File "$baseDir/objects/Booking__c/fields/Tower_Incharge__c.field-meta.xml" (New-LookupField "Tower_Incharge__c" "User" "Managed Bookings" "Managed_Bookings")
Write-Utf8File "$baseDir/tabs/Booking__c.tab-meta.xml" (New-TabXml "Booking__c" "Custom45: Ticket")

# 9. Booking_Applicant__c
Write-Utf8File "$baseDir/objects/Booking_Applicant__c/Booking_Applicant__c.object-meta.xml" (New-ObjectXml "Booking Applicant" "Booking Applicants" "ControlledByParent" "Applicant Number" "AutoNumber" "APP-{0000}")
Write-Utf8File "$baseDir/objects/Booking_Applicant__c/fields/Booking__c.field-meta.xml" (New-MasterDetailField "Booking__c" "Booking__c" "Booking Applicants" "Booking_Applicants")
Write-Utf8File "$baseDir/objects/Booking_Applicant__c/fields/Contact__c.field-meta.xml" (New-LookupField "Contact__c" "Contact" "Booking Applications" "Booking_Applications")
Write-Utf8File "$baseDir/objects/Booking_Applicant__c/fields/Applicant_Role__c.field-meta.xml" (New-PicklistField "Applicant_Role__c" @("Primary Applicant", "Co-Applicant", "Nominee"))
Write-Utf8File "$baseDir/objects/Booking_Applicant__c/fields/Is_Financial_Applicant__c.field-meta.xml" (New-CheckboxField "Is_Financial_Applicant__c" $false)
Write-Utf8File "$baseDir/objects/Booking_Applicant__c/fields/PAN__c.field-meta.xml" (New-TextField "PAN__c" 10)
Write-Utf8File "$baseDir/objects/Booking_Applicant__c/fields/Aadhaar_Masked__c.field-meta.xml" (New-TextField "Aadhaar_Masked__c" 12)
Write-Utf8File "$baseDir/objects/Booking_Applicant__c/fields/KYC_Status__c.field-meta.xml" (New-PicklistField "KYC_Status__c" @("Pending", "Submitted", "Verified", "Rejected"))
Write-Utf8File "$baseDir/tabs/Booking_Applicant__c.tab-meta.xml" (New-TabXml "Booking_Applicant__c" "Custom15: People")

# 10. Installment__c
Write-Utf8File "$baseDir/objects/Installment__c/Installment__c.object-meta.xml" (New-ObjectXml "Installment" "Installments" "ControlledByParent" "Installment Number" "AutoNumber" "INST-{0000}")
Write-Utf8File "$baseDir/objects/Installment__c/fields/Booking__c.field-meta.xml" (New-MasterDetailField "Booking__c" "Booking__c" "Installments" "Installments")
Write-Utf8File "$baseDir/objects/Installment__c/fields/Payment_Milestone__c.field-meta.xml" (New-LookupField "Payment_Milestone__c" "Payment_Milestone__c" "Installments" "Installments")
Write-Utf8File "$baseDir/objects/Installment__c/fields/Due_Date__c.field-meta.xml" (New-DateField "Due_Date__c")
Write-Utf8File "$baseDir/objects/Installment__c/fields/Amount__c.field-meta.xml" (New-CurrencyField "Amount__c" 18 2)
Write-Utf8File "$baseDir/objects/Installment__c/fields/Paid_Amount__c.field-meta.xml" (New-CurrencyField "Paid_Amount__c" 18 2)
Write-Utf8File "$baseDir/objects/Installment__c/fields/Outstanding_Amount__c.field-meta.xml" (New-FormulaCurrencyField "Outstanding_Amount__c" "Amount__c - BLANKVALUE(Paid_Amount__c, 0)")
Write-Utf8File "$baseDir/objects/Installment__c/fields/Status__c.field-meta.xml" (New-PicklistField "Status__c" @("Upcoming", "Due", "Paid", "Overdue"))
Write-Utf8File "$baseDir/objects/Installment__c/fields/Overdue_Interest__c.field-meta.xml" (New-CurrencyField "Overdue_Interest__c" 18 2)
Write-Utf8File "$baseDir/objects/Installment__c/fields/Days_Overdue__c.field-meta.xml" (New-NumberField "Days_Overdue__c" 5 0)
Write-Utf8File "$baseDir/objects/Installment__c/fields/Interest_Waived__c.field-meta.xml" (New-CheckboxField "Interest_Waived__c" $false)
Write-Utf8File "$baseDir/tabs/Installment__c.tab-meta.xml" (New-TabXml "Installment__c" "Custom16: Bank")

# 11. Receipt__c
Write-Utf8File "$baseDir/objects/Receipt__c/Receipt__c.object-meta.xml" (New-ObjectXml "Receipt" "Receipts" "ReadWrite" "Receipt Number" "AutoNumber" "RCPT-{0000}")
Write-Utf8File "$baseDir/objects/Receipt__c/fields/Installment__c.field-meta.xml" (New-LookupField "Installment__c" "Installment__c" "Receipts" "Receipts")
Write-Utf8File "$baseDir/objects/Receipt__c/fields/Receipt_Date__c.field-meta.xml" (New-DateField "Receipt_Date__c")
Write-Utf8File "$baseDir/objects/Receipt__c/fields/Amount__c.field-meta.xml" (New-CurrencyField "Amount__c" 18 2)
Write-Utf8File "$baseDir/objects/Receipt__c/fields/Payment_Mode__c.field-meta.xml" (New-PicklistField "Payment_Mode__c" @("Cheque", "NEFT/RTGS", "UPI", "Credit Card", "Demand Draft"))
Write-Utf8File "$baseDir/objects/Receipt__c/fields/Transaction_Reference__c.field-meta.xml" (New-TextField "Transaction_Reference__c" 100)
Write-Utf8File "$baseDir/objects/Receipt__c/fields/Status__c.field-meta.xml" (New-PicklistField "Status__c" @("Pending Reconciliation", "Confirmed", "Rejected"))
Write-Utf8File "$baseDir/objects/Receipt__c/fields/Reconciliation_Notes__c.field-meta.xml" (New-TextAreaField "Reconciliation_Notes__c")
Write-Utf8File "$baseDir/tabs/Receipt__c.tab-meta.xml" (New-TabXml "Receipt__c" "Custom41: Cash")

# 12. Cancellation_Request__c
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/Cancellation_Request__c.object-meta.xml" (New-ObjectXml "Cancellation Request" "Cancellation Requests" "ReadWrite" "Cancellation Number" "AutoNumber" "CAN-{0000}")
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/fields/Booking__c.field-meta.xml" (New-LookupField "Booking__c" "Booking__c" "Cancellation Requests" "Cancellation_Requests")
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/fields/Request_Date__c.field-meta.xml" (New-DateField "Request_Date__c")
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/fields/Reason__c.field-meta.xml" (New-PicklistField "Reason__c" @("Financial Constraints", "Relocation", "Personal Reasons", "Found Better Property", "Project Delay"))
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/fields/Status__c.field-meta.xml" (New-PicklistField "Status__c" @("Draft", "Under Review", "Approved", "Rejected", "Refund Processed"))
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/fields/Total_Paid_Amount__c.field-meta.xml" (New-CurrencyField "Total_Paid_Amount__c" 18 2)
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/fields/Cancellation_Charges__c.field-meta.xml" (New-CurrencyField "Cancellation_Charges__c" 18 2)
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/fields/Refund_Amount__c.field-meta.xml" (New-CurrencyField "Refund_Amount__c" 18 2)
Write-Utf8File "$baseDir/objects/Cancellation_Request__c/fields/Remarks__c.field-meta.xml" (New-LongTextAreaField "Remarks__c")
Write-Utf8File "$baseDir/tabs/Cancellation_Request__c.tab-meta.xml" (New-TabXml "Cancellation_Request__c" "Custom37: Bridge")

# -------------------------------------------------------------
# STANDARD OBJECT CUSTOM FIELDS
# -------------------------------------------------------------
# Opportunity
Write-Utf8File "$baseDir/objects/Opportunity/fields/Project__c.field-meta.xml" (New-LookupField "Project__c" "Project__c" "Opportunities" "Opportunities")
Write-Utf8File "$baseDir/objects/Opportunity/fields/Tagged_Unit__c.field-meta.xml" (New-LookupField "Tagged_Unit__c" "Unit__c" "Tagged Opportunities" "Tagged_Opportunities")
Write-Utf8File "$baseDir/objects/Opportunity/fields/Booking_Form_Approved__c.field-meta.xml" (New-CheckboxField "Booking_Form_Approved__c" $false)
Write-Utf8File "$baseDir/objects/Opportunity/fields/Token_Payment_Received__c.field-meta.xml" (New-CheckboxField "Token_Payment_Received__c" $false)

# Lead
Write-Utf8File "$baseDir/objects/Lead/fields/Project_Enquired__c.field-meta.xml" (New-LookupField "Project_Enquired__c" "Project__c" "Leads" "Leads")
Write-Utf8File "$baseDir/objects/Lead/fields/Budget_Range__c.field-meta.xml" (New-PicklistField "Budget_Range__c" @("50L - 1 Cr", "1 Cr - 2 Cr", "2 Cr - 3.5 Cr", "3.5 Cr+"))
Write-Utf8File "$baseDir/objects/Lead/fields/Configuration_Interested__c.field-meta.xml" (New-PicklistField "Configuration_Interested__c" @("1 BHK", "2 BHK", "2.5 BHK", "3 BHK", "4 BHK", "Penthouse"))

# Account
Write-Utf8File "$baseDir/objects/Account/fields/RERA_Number__c.field-meta.xml" (New-TextField "RERA_Number__c" 50)
Write-Utf8File "$baseDir/objects/Account/fields/Agency_Name__c.field-meta.xml" (New-TextField "Agency_Name__c" 100)

# Account Record Types
Write-Utf8File "$baseDir/objects/Account/recordTypes/Customer.recordType-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<RecordType xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Customer</fullName>
    <active>true</active>
    <description>Individual buyer or property owner account</description>
    <label>Customer</label>
</RecordType>
"@

Write-Utf8File "$baseDir/objects/Account/recordTypes/Channel_Partner.recordType-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<RecordType xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Channel_Partner</fullName>
    <active>true</active>
    <description>Real estate broker or channel partner agency</description>
    <label>Channel Partner</label>
</RecordType>
"@

Write-Host "Scaffolding completed successfully."
