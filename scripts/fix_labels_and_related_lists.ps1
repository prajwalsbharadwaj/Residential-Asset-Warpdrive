# scripts/fix_labels_and_related_lists.ps1

$baseDir = "force-app/main/default"

# -------------------------------------------------------------
# 1. CLEAN HUMAN LABELS MAP
# -------------------------------------------------------------
$labelMap = @{
    # Project__c
    "Project__c.Location__c" = "Location"
    "Project__c.Status__c" = "Project Status"
    "Project__c.RERA_Registration_Number__c" = "RERA Registration Number"
    "Project__c.Total_Towers__c" = "Total Towers"
    "Project__c.Description__c" = "Project Description"

    # Tower__c
    "Tower__c.Project__c" = "Project"
    "Tower__c.Total_Floors__c" = "Total Floors"
    "Tower__c.Construction_Status__c" = "Construction Status"

    # Floor__c
    "Floor__c.Tower__c" = "Tower"
    "Floor__c.Floor_Number__c" = "Floor Number"
    "Floor__c.Units_Per_Floor__c" = "Units Per Floor"

    # Unit__c
    "Unit__c.Floor__c" = "Floor"
    "Unit__c.Configuration__c" = "Unit Configuration"
    "Unit__c.Carpet_Area_SqFt__c" = "Carpet Area (Sq Ft)"
    "Unit__c.Super_Built_Up_Area_SqFt__c" = "Super Built-Up Area (Sq Ft)"
    "Unit__c.Base_Price__c" = "Base Price"
    "Unit__c.Total_Price__c" = "Total Price"
    "Unit__c.Status__c" = "Unit Status"
    "Unit__c.SAP_Material_Code__c" = "SAP Material Code"

    # Site_Visit__c
    "Site_Visit__c.Lead__c" = "Lead"
    "Site_Visit__c.Opportunity__c" = "Opportunity"
    "Site_Visit__c.Customer__c" = "Customer Account"
    "Site_Visit__c.Project__c" = "Project"
    "Site_Visit__c.Visit_Date_Time__c" = "Visit Date & Time"
    "Site_Visit__c.Status__c" = "Visit Status"
    "Site_Visit__c.Rating__c" = "Visitor Rating"
    "Site_Visit__c.Feedback__c" = "Visit Feedback"
    "Site_Visit__c.Sales_Executive__c" = "Sales Executive"

    # Payment_Plan__c
    "Payment_Plan__c.Project__c" = "Project"
    "Payment_Plan__c.Plan_Type__c" = "Plan Type"
    "Payment_Plan__c.Active__c" = "Active"
    "Payment_Plan__c.Description__c" = "Plan Description"

    # Payment_Milestone__c
    "Payment_Milestone__c.Payment_Plan__c" = "Payment Plan"
    "Payment_Milestone__c.Milestone_Percentage__c" = "Milestone Percentage (%)"
    "Payment_Milestone__c.Milestone_Order__c" = "Milestone Sequence"
    "Payment_Milestone__c.Trigger_Event__c" = "Construction Trigger Event"
    "Payment_Milestone__c.Days_From_Booking__c" = "Days From Booking"

    # Booking__c
    "Booking__c.Opportunity__c" = "Opportunity"
    "Booking__c.Customer__c" = "Customer Account"
    "Booking__c.Unit__c" = "Booked Unit"
    "Booking__c.Payment_Plan__c" = "Payment Plan"
    "Booking__c.Booking_Date__c" = "Booking Date"
    "Booking__c.Total_Booking_Amount__c" = "Total Booking Amount"
    "Booking__c.Status__c" = "Booking Status"
    "Booking__c.SAP_Customer_Code__c" = "SAP Customer Code"
    "Booking__c.Tower_Incharge__c" = "Tower Incharge"

    # Booking_Applicant__c
    "Booking_Applicant__c.Booking__c" = "Booking"
    "Booking_Applicant__c.Contact__c" = "Applicant Contact"
    "Booking_Applicant__c.Applicant_Role__c" = "Applicant Role"
    "Booking_Applicant__c.Is_Financial_Applicant__c" = "Is Financial Applicant"
    "Booking_Applicant__c.PAN__c" = "PAN Number"
    "Booking_Applicant__c.Aadhaar_Masked__c" = "Aadhaar (Masked)"
    "Booking_Applicant__c.KYC_Status__c" = "KYC Verification Status"

    # Installment__c
    "Installment__c.Booking__c" = "Booking"
    "Installment__c.Payment_Milestone__c" = "Payment Milestone"
    "Installment__c.Due_Date__c" = "Due Date"
    "Installment__c.Amount__c" = "Installment Amount"
    "Installment__c.Paid_Amount__c" = "Paid Amount"
    "Installment__c.Outstanding_Amount__c" = "Outstanding Amount"
    "Installment__c.Status__c" = "Installment Status"
    "Installment__c.Overdue_Interest__c" = "Overdue Interest (18% p.a.)"
    "Installment__c.Days_Overdue__c" = "Days Overdue"
    "Installment__c.Interest_Waived__c" = "Interest Waived"

    # Receipt__c
    "Receipt__c.Installment__c" = "Installment"
    "Receipt__c.Receipt_Date__c" = "Receipt Date"
    "Receipt__c.Amount__c" = "Receipt Amount"
    "Receipt__c.Payment_Mode__c" = "Payment Mode"
    "Receipt__c.Transaction_Reference__c" = "Transaction / UTR Reference"
    "Receipt__c.Status__c" = "Receipt Status"
    "Receipt__c.Reconciliation_Notes__c" = "Reconciliation Notes"

    # Cancellation_Request__c
    "Cancellation_Request__c.Booking__c" = "Booking"
    "Cancellation_Request__c.Request_Date__c" = "Request Date"
    "Cancellation_Request__c.Reason__c" = "Cancellation Reason"
    "Cancellation_Request__c.Status__c" = "Cancellation Status"
    "Cancellation_Request__c.Total_Paid_Amount__c" = "Total Paid Amount"
    "Cancellation_Request__c.Cancellation_Charges__c" = "Cancellation Charges"
    "Cancellation_Request__c.Refund_Amount__c" = "Refund Amount"
    "Cancellation_Request__c.Remarks__c" = "Remarks"

    # Standard Object Fields
    "Opportunity.Project__c" = "Project"
    "Opportunity.Tagged_Unit__c" = "Tagged Unit"
    "Opportunity.Booking_Form_Approved__c" = "Booking Form Approved"
    "Opportunity.Token_Payment_Received__c" = "Token Payment Received"

    "Lead.Project_Enquired__c" = "Project Enquired"
    "Lead.Budget_Range__c" = "Budget Range"
    "Lead.Configuration_Interested__c" = "Configuration Interested"

    "Account.RERA_Number__c" = "RERA Registration Number"
    "Account.Agency_Name__c" = "Agency Name"
}

Write-Host "Updating field labels across objects..."

foreach ($key in $labelMap.Keys) {
    $parts = $key.Split('.')
    $objName = $parts[0]
    $fieldName = $parts[1]
    
    $filePath = "$baseDir/objects/$objName/fields/$fieldName.field-meta.xml"
    if (Test-Path $filePath) {
        $cleanLabel = $labelMap[$key]
        $content = Get-Content $filePath -Raw
        $newContent = [regex]::Replace($content, "<label>.*?</label>", "<label>$cleanLabel</label>")
        [System.IO.File]::WriteAllText($filePath, $newContent, [System.Text.Encoding]::UTF8)
        Write-Host "Updated $key -> $cleanLabel"
    }
}

# -------------------------------------------------------------
# 2. PAGE LAYOUTS WITH RELATED LISTS
# -------------------------------------------------------------
function New-LayoutWithRelatedLists($objectLabel, $fieldsLeft, $fieldsRight, $reqName = $false, $relatedLists = @()) {
    $leftItems = ($fieldsLeft | ForEach-Object {
        $beh = "Edit"
        if ($_ -eq "Name" -and $reqName) { $beh = "Required" }
        if ($_ -eq "Outstanding_Amount__c") { $beh = "Readonly" }
        @"
                <layoutItems>
                    <behavior>$beh</behavior>
                    <field>$_</field>
                </layoutItems>
"@
    }) -join "`n"

    $rightItems = ($fieldsRight | ForEach-Object {
        $beh = "Edit"
        if ($_ -eq "Name" -and $reqName) { $beh = "Required" }
        if ($_ -eq "Outstanding_Amount__c") { $beh = "Readonly" }
        @"
                <layoutItems>
                    <behavior>$beh</behavior>
                    <field>$_</field>
                </layoutItems>
"@
    }) -join "`n"

    $relListsXml = ($relatedLists | ForEach-Object {
        $relName = $_.rel
        $fieldsXml = ($_.cols | ForEach-Object { "<fields>$_</fields>" }) -join "`n        "
        @"
    <relatedLists>
        $fieldsXml
        <relatedList>$relName</relatedList>
    </relatedLists>
"@
    }) -join "`n"

    return @"
<?xml version="1.0" encoding="UTF-8"?>
<Layout xmlns="http://soap.sforce.com/2006/04/metadata">
    <excludeButtons>Submit</excludeButtons>
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>true</editHeading>
        <label>Information</label>
        <layoutColumns>
$leftItems
        </layoutColumns>
        <layoutColumns>
$rightItems
        </layoutColumns>
        <style>TwoColumnsTopToBottom</style>
    </layoutSections>
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>true</detailHeading>
        <editHeading>true</editHeading>
        <label>System Information</label>
        <layoutColumns>
            <layoutItems>
                <behavior>Readonly</behavior>
                <field>CreatedById</field>
            </layoutItems>
        </layoutColumns>
        <layoutColumns>
            <layoutItems>
                <behavior>Readonly</behavior>
                <field>LastModifiedById</field>
            </layoutItems>
        </layoutColumns>
        <style>TwoColumnsTopToBottom</style>
    </layoutSections>
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>true</editHeading>
        <label>Custom Links</label>
        <layoutColumns/>
        <layoutColumns/>
        <layoutColumns/>
        <style>CustomLinks</style>
    </layoutSections>
$relListsXml
    <showEmailCheckbox>false</showEmailCheckbox>
    <showHighlightsPanel>false</showHighlightsPanel>
    <showInteractionLogPanel>false</showInteractionLogPanel>
    <showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>
    <showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>
"@
}

# 1. Project Layout (TOWERS in related list, plus Payment Plans and Site Visits)
$projRels = @(
    @{ rel = "Tower__c.Project__c"; cols = @("NAME", "Construction_Status__c", "Total_Floors__c") },
    @{ rel = "Payment_Plan__c.Project__c"; cols = @("NAME", "Plan_Type__c", "Active__c") },
    @{ rel = "Site_Visit__c.Project__c"; cols = @("NAME", "Visit_Date_Time__c", "Status__c", "Rating__c") },
    @{ rel = "Opportunity.Project__c"; cols = @("OPPORTUNITY.NAME", "OPPORTUNITY.STAGE_NAME", "OPPORTUNITY.AMOUNT") }
)
$projLayout = New-LayoutWithRelatedLists "Project" @("Name", "Location__c", "Status__c") @("RERA_Registration_Number__c", "Total_Towers__c", "Description__c") $true $projRels
[System.IO.File]::WriteAllText("$baseDir/layouts/Project__c-Project Layout.layout-meta.xml", $projLayout, [System.Text.Encoding]::UTF8)

# 2. Tower Layout (Floors related list)
$towerRels = @(
    @{ rel = "Floor__c.Tower__c"; cols = @("NAME", "Floor_Number__c", "Units_Per_Floor__c") }
)
$towerLayout = New-LayoutWithRelatedLists "Tower" @("Name", "Project__c") @("Construction_Status__c", "Total_Floors__c") $true $towerRels
[System.IO.File]::WriteAllText("$baseDir/layouts/Tower__c-Tower Layout.layout-meta.xml", $towerLayout, [System.Text.Encoding]::UTF8)

# 3. Floor Layout (Units related list)
$floorRels = @(
    @{ rel = "Unit__c.Floor__c"; cols = @("NAME", "Configuration__c", "Status__c", "Total_Price__c", "Carpet_Area_SqFt__c") }
)
$floorLayout = New-LayoutWithRelatedLists "Floor" @("Name", "Tower__c") @("Floor_Number__c", "Units_Per_Floor__c") $true $floorRels
[System.IO.File]::WriteAllText("$baseDir/layouts/Floor__c-Floor Layout.layout-meta.xml", $floorLayout, [System.Text.Encoding]::UTF8)

# 4. Payment Plan Layout (Milestones related list)
$planRels = @(
    @{ rel = "Payment_Milestone__c.Payment_Plan__c"; cols = @("NAME", "Milestone_Order__c", "Milestone_Percentage__c", "Trigger_Event__c") }
)
$planLayout = New-LayoutWithRelatedLists "Payment Plan" @("Name", "Project__c", "Plan_Type__c") @("Active__c", "Description__c") $true $planRels
[System.IO.File]::WriteAllText("$baseDir/layouts/Payment_Plan__c-Payment Plan Layout.layout-meta.xml", $planLayout, [System.Text.Encoding]::UTF8)

# 5. Booking Layout (Applicants, Installments, Cancellation Requests)
$bkgRels = @(
    @{ rel = "Booking_Applicant__c.Booking__c"; cols = @("NAME", "Contact__c", "Applicant_Role__c", "Is_Financial_Applicant__c", "KYC_Status__c") },
    @{ rel = "Installment__c.Booking__c"; cols = @("NAME", "Payment_Milestone__c", "Due_Date__c", "Status__c", "Amount__c", "Outstanding_Amount__c", "Overdue_Interest__c") },
    @{ rel = "Cancellation_Request__c.Booking__c"; cols = @("NAME", "Request_Date__c", "Reason__c", "Status__c", "Refund_Amount__c") }
)
$bkgLayout = New-LayoutWithRelatedLists "Booking" @("Opportunity__c", "Customer__c", "Unit__c", "Payment_Plan__c", "Booking_Date__c") @("Total_Booking_Amount__c", "Status__c", "SAP_Customer_Code__c", "Tower_Incharge__c") $false $bkgRels
[System.IO.File]::WriteAllText("$baseDir/layouts/Booking__c-Booking Layout.layout-meta.xml", $bkgLayout, [System.Text.Encoding]::UTF8)

# 6. Installment Layout (Receipts related list)
$instRels = @(
    @{ rel = "Receipt__c.Installment__c"; cols = @("NAME", "Receipt_Date__c", "Amount__c", "Payment_Mode__c", "Status__c", "Transaction_Reference__c") }
)
$instLayout = New-LayoutWithRelatedLists "Installment" @("Booking__c", "Payment_Milestone__c", "Due_Date__c", "Status__c") @("Amount__c", "Paid_Amount__c", "Outstanding_Amount__c", "Overdue_Interest__c", "Days_Overdue__c", "Interest_Waived__c") $false $instRels
[System.IO.File]::WriteAllText("$baseDir/layouts/Installment__c-Installment Layout.layout-meta.xml", $instLayout, [System.Text.Encoding]::UTF8)

Write-Host "Labels and Layouts with related lists generated successfully."
