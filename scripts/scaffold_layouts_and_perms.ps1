# scripts/scaffold_layouts_and_perms.ps1

$baseDir = "force-app/main/default"

function Write-Utf8File($path, $content) {
    $parent = Split-Path $path
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
}

function New-SimpleLayout($objectLabel, $fieldsLeft, $fieldsRight, $relatedLists = @()) {
    $leftItems = ($fieldsLeft | ForEach-Object {
        @"
                <layoutItems>
                    <behavior>Edit</behavior>
                    <field>$_</field>
                </layoutItems>
"@
    }) -join "`n"

    $rightItems = ($fieldsRight | ForEach-Object {
        @"
                <layoutItems>
                    <behavior>Edit</behavior>
                    <field>$_</field>
                </layoutItems>
"@
    }) -join "`n"

    $relListsXml = ($relatedLists | ForEach-Object {
        @"
    <relatedLists>
        <fields>NAME</fields>
        <relatedList>$_</relatedList>
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

# 1. Project Layout
Write-Utf8File "$baseDir/layouts/Project__c-Project Layout.layout-meta.xml" (
    New-SimpleLayout "Project" @("Name", "Location__c", "Status__c") @("RERA_Registration_Number__c", "Total_Towers__c", "Description__c") @("Towers__r", "Payment_Plans__r", "Site_Visits__r")
)

# 2. Tower Layout
Write-Utf8File "$baseDir/layouts/Tower__c-Tower Layout.layout-meta.xml" (
    New-SimpleLayout "Tower" @("Name", "Project__c") @("Construction_Status__c", "Total_Floors__c") @("Floors__r")
)

# 3. Floor Layout
Write-Utf8File "$baseDir/layouts/Floor__c-Floor Layout.layout-meta.xml" (
    New-SimpleLayout "Floor" @("Name", "Tower__c") @("Floor_Number__c", "Units_Per_Floor__c") @("Units__r")
)

# 4. Unit Layout
Write-Utf8File "$baseDir/layouts/Unit__c-Unit Layout.layout-meta.xml" (
    New-SimpleLayout "Unit" @("Name", "Floor__c", "Configuration__c", "Status__c") @("Carpet_Area_SqFt__c", "Super_Built_Up_Area_SqFt__c", "Base_Price__c", "Total_Price__c", "SAP_Material_Code__c") @("Bookings__r")
)

# 5. Site Visit Layout
Write-Utf8File "$baseDir/layouts/Site_Visit__c-Site Visit Layout.layout-meta.xml" (
    New-SimpleLayout "Site Visit" @("Visit_Date_Time__c", "Project__c", "Lead__c", "Opportunity__c", "Customer__c") @("Status__c", "Rating__c", "Sales_Executive__c", "Feedback__c")
)

# 6. Payment Plan Layout
Write-Utf8File "$baseDir/layouts/Payment_Plan__c-Payment Plan Layout.layout-meta.xml" (
    New-SimpleLayout "Payment Plan" @("Name", "Project__c", "Plan_Type__c") @("Active__c", "Description__c") @("Payment_Milestones__r", "Bookings__r")
)

# 7. Payment Milestone Layout
Write-Utf8File "$baseDir/layouts/Payment_Milestone__c-Payment Milestone Layout.layout-meta.xml" (
    New-SimpleLayout "Payment Milestone" @("Name", "Payment_Plan__c", "Milestone_Order__c") @("Milestone_Percentage__c", "Trigger_Event__c", "Days_From_Booking__c") @("Installments__r")
)

# 8. Booking Layout
Write-Utf8File "$baseDir/layouts/Booking__c-Booking Layout.layout-meta.xml" (
    New-SimpleLayout "Booking" @("Opportunity__c", "Customer__c", "Unit__c", "Payment_Plan__c", "Booking_Date__c") @("Total_Booking_Amount__c", "Status__c", "SAP_Customer_Code__c", "Tower_Incharge__c") @("Booking_Applicants__r", "Installments__r", "Cancellation_Requests__r")
)

# 9. Booking Applicant Layout
Write-Utf8File "$baseDir/layouts/Booking_Applicant__c-Booking Applicant Layout.layout-meta.xml" (
    New-SimpleLayout "Booking Applicant" @("Booking__c", "Contact__c", "Applicant_Role__c") @("Is_Financial_Applicant__c", "PAN__c", "Aadhaar_Masked__c", "KYC_Status__c")
)

# 10. Installment Layout
Write-Utf8File "$baseDir/layouts/Installment__c-Installment Layout.layout-meta.xml" (
    New-SimpleLayout "Installment" @("Booking__c", "Payment_Milestone__c", "Due_Date__c", "Status__c") @("Amount__c", "Paid_Amount__c", "Outstanding_Amount__c", "Overdue_Interest__c", "Days_Overdue__c", "Interest_Waived__c") @("Receipts__r")
)

# 11. Receipt Layout
Write-Utf8File "$baseDir/layouts/Receipt__c-Receipt Layout.layout-meta.xml" (
    New-SimpleLayout "Receipt" @("Installment__c", "Receipt_Date__c", "Amount__c") @("Payment_Mode__c", "Transaction_Reference__c", "Status__c", "Reconciliation_Notes__c") @("ProcessSteps")
)

# 12. Cancellation Request Layout
Write-Utf8File "$baseDir/layouts/Cancellation_Request__c-Cancellation Request Layout.layout-meta.xml" (
    New-SimpleLayout "Cancellation Request" @("Booking__c", "Request_Date__c", "Reason__c", "Status__c") @("Total_Paid_Amount__c", "Cancellation_Charges__c", "Refund_Amount__c", "Remarks__c")
)

# -------------------------------------------------------------
# PERMISSION SETS
# -------------------------------------------------------------
function New-PermSet($name, $label, $desc, $objPerms, $tabVisibilities) {
    $objXml = ($objPerms | ForEach-Object {
        @"
    <objectPermissions>
        <allowCreate>$($_.c)</allowCreate>
        <allowDelete>$($_.d)</allowDelete>
        <allowEdit>$($_.e)</allowEdit>
        <allowRead>$($_.r)</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>$($_.obj)</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>
"@
    }) -join "`n"

    $tabXml = ($tabVisibilities | ForEach-Object {
        @"
    <tabSettings>
        <tab>$_</tab>
        <visibility>Visible</visibility>
    </tabSettings>
"@
    }) -join "`n"

    return @"
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <applicationVisibilities>
        <application>Residential_Sales_CRM</application>
        <visible>true</visible>
    </applicationVisibilities>
    <description>$desc</description>
    <hasActivationRequired>false</hasActivationRequired>
    <label>$label</label>
$objXml
$tabXml
</PermissionSet>
"@
}

# Sales_Exec_Demo
$salesObjs = @(
    @{ obj="Lead"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Opportunity"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Quote"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Site_Visit__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Project__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Tower__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Floor__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Unit__c"; r="true"; c="false"; e="false"; d="false" }
)
$salesTabs = @("Site_Visit__c", "Project__c", "Tower__c", "Floor__c", "Unit__c")
Write-Utf8File "$baseDir/permissionsets/Sales_Exec_Demo.permissionset-meta.xml" (New-PermSet "Sales_Exec_Demo" "Sales Exec Demo" "Sales Executive access for Lead, Opportunity, Quote, Site Visits and Inventory" $salesObjs $salesTabs)

# CRM_Team_Demo
$crmObjs = @(
    @{ obj="Booking__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Booking_Applicant__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Installment__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Receipt__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Unit__c"; r="true"; c="false"; e="true"; d="false" },
    @{ obj="Payment_Plan__c"; r="true"; c="false"; e="false"; d="false" }
)
$crmTabs = @("Booking__c", "Booking_Applicant__c", "Installment__c", "Receipt__c", "Unit__c", "Payment_Plan__c")
Write-Utf8File "$baseDir/permissionsets/CRM_Team_Demo.permissionset-meta.xml" (New-PermSet "CRM_Team_Demo" "CRM Team Demo" "CRM Team access for Bookings, Applicants, Installments, Receipts" $crmObjs $crmTabs)

# Finance_Demo
$finObjs = @(
    @{ obj="Receipt__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Cancellation_Request__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Installment__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Booking__c"; r="true"; c="false"; e="true"; d="false" }
)
$finTabs = @("Receipt__c", "Cancellation_Request__c", "Installment__c", "Booking__c")
Write-Utf8File "$baseDir/permissionsets/Finance_Demo.permissionset-meta.xml" (New-PermSet "Finance_Demo" "Finance Demo" "Finance team access to approve and reconcile Receipts and Cancellation Requests" $finObjs $finTabs)

Write-Host "Layouts and Permission Sets generated."
