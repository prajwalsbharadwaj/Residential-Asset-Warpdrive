# scripts/generate_admin_permset.ps1

$baseDir = "force-app/main/default"

$fields = @()
$customObjects = Get-ChildItem "$baseDir/objects" -Directory

foreach ($objDir in $customObjects) {
    $objName = $objDir.Name
    $fieldsDir = Join-Path $objDir.FullName "fields"
    if (Test-Path $fieldsDir) {
        $fieldFiles = Get-ChildItem $fieldsDir -Filter "*.field-meta.xml"
        foreach ($f in $fieldFiles) {
            $fName = $f.Name.Replace(".field-meta.xml", "")
            $content = Get-Content $f.FullName -Raw
            
            $isRequired = $content -match "<required>true</required>"
            $isMasterDetail = $content -match "<type>MasterDetail</type>"
            $isFormula = $content -match "<formula>"
            
            # MasterDetail and Required fields cannot be in fieldPermissions!
            if ($isRequired -or $isMasterDetail) {
                continue
            }
            
            $fields += [PSCustomObject]@{
                ObjField = "$objName.$fName"
                Editable = if ($isFormula) { "false" } else { "true" }
                Readable = "true"
            }
        }
    }
}

# Sort fields
$fields = $fields | Sort-Object ObjField

$fieldPermXml = ($fields | ForEach-Object {
    @"
    <fieldPermissions>
        <editable>$($_.Editable)</editable>
        <field>$($_.ObjField)</field>
        <readable>$($_.Readable)</readable>
    </fieldPermissions>
"@
}) -join "`n"

$allObjs = @(
    "Lead", "Account", "Contact", "Opportunity", "Quote",
    "Project__c", "Tower__c", "Floor__c", "Unit__c", "Site_Visit__c",
    "Payment_Plan__c", "Payment_Milestone__c", "Booking__c",
    "Booking_Applicant__c", "Installment__c", "Receipt__c", "Cancellation_Request__c"
)

$objPermXml = ($allObjs | ForEach-Object {
    @"
    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>true</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>true</modifyAllRecords>
        <object>$_</object>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>
"@
}) -join "`n"

$tabs = @(
    "Project__c", "Tower__c", "Floor__c", "Unit__c", "Site_Visit__c",
    "Payment_Plan__c", "Payment_Milestone__c", "Booking__c",
    "Booking_Applicant__c", "Installment__c", "Receipt__c", "Cancellation_Request__c"
)

$tabPermXml = ($tabs | ForEach-Object {
    @"
    <tabSettings>
        <tab>$_</tab>
        <visibility>Visible</visibility>
    </tabSettings>
"@
}) -join "`n"

$permSetXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <applicationVisibilities>
        <application>Residential_Sales_CRM</application>
        <visible>true</visible>
    </applicationVisibilities>
    <description>Full Admin and Execution permissions across all Residential Sales objects and fields</description>
    <hasActivationRequired>false</hasActivationRequired>
    <label>Residential Sales Admin</label>
$fieldPermXml
$objPermXml
$tabPermXml
</PermissionSet>
"@

[System.IO.File]::WriteAllText("$baseDir/permissionsets/Residential_Sales_Admin.permissionset-meta.xml", $permSetXml, [System.Text.Encoding]::UTF8)
Write-Host "Regenerated Residential_Sales_Admin.permissionset-meta.xml with $($fields.Count) fields."
