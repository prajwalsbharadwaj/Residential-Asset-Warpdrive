# scripts/update_admin_profile.ps1

$baseDir = "force-app/main/default"
$profilePath = "$baseDir/profiles/Admin.profile-meta.xml"

# 1. Gather all fields
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

# 2. Objects
$customObjs = @(
    "Project__c", "Tower__c", "Floor__c", "Unit__c", "Site_Visit__c",
    "Payment_Plan__c", "Payment_Milestone__c", "Booking__c",
    "Booking_Applicant__c", "Installment__c", "Receipt__c", "Cancellation_Request__c"
) | Sort-Object

$objPermXml = ($customObjs | ForEach-Object {
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

# 3. Tabs
$tabs = $customObjs | Sort-Object
$tabPermXml = ($tabs | ForEach-Object {
    @"
    <tabVisibilities>
        <tab>$_</tab>
        <visibility>DefaultOn</visibility>
    </tabVisibilities>
"@
}) -join "`n"

# 4. Record Types
$rtXml = @"
    <recordTypeVisibilities>
        <default>false</default>
        <recordType>Account.Channel_Partner</recordType>
        <visible>true</visible>
    </recordTypeVisibilities>
    <recordTypeVisibilities>
        <default>true</default>
        <recordType>Account.Customer</recordType>
        <visible>true</visible>
    </recordTypeVisibilities>
    <recordTypeVisibilities>
        <default>true</default>
        <recordType>Opportunity.Residential_Sales</recordType>
        <visible>true</visible>
    </recordTypeVisibilities>
"@

# 5. App
$appXml = @"
    <applicationVisibilities>
        <application>Residential_Sales_CRM</application>
        <default>true</default>
        <visible>true</visible>
    </applicationVisibilities>
"@

# Read existing Admin profile
$content = Get-Content $profilePath -Raw

# Replace or insert tags in exact alphabetical order:
# 1. <applicationVisibilities> right after <custom>false</custom>
# 2. <fieldPermissions> right after </custom> or before loginIpRanges
# 3. <objectPermissions> after loginIpRanges
# 4. <recordTypeVisibilities> after objectPermissions
# 5. <tabVisibilities> after recordTypeVisibilities

# Remove any existing custom blocks we might add
$content = $content -replace "(?s)<applicationVisibilities>.*?<\/applicationVisibilities>", ""
$content = $content -replace "(?s)<fieldPermissions>.*?<\/fieldPermissions>", ""
$content = $content -replace "(?s)<objectPermissions>.*?<\/objectPermissions>", ""
$content = $content -replace "(?s)<tabVisibilities>.*?<\/tabVisibilities>", ""
$content = $content -replace "(?s)<recordTypeVisibilities>.*?<\/recordTypeVisibilities>", ""

# Rebuild Admin Profile cleanly
$header = @"
<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
$appXml
    <custom>false</custom>
$fieldPermXml
    <loginIpRanges>
        <endAddress>255.255.255.255</endAddress>
        <startAddress>0.0.0.0</startAddress>
    </loginIpRanges>
$objPermXml
$rtXml
$tabPermXml
    <userLicense>Salesforce</userLicense>
"@

# Extract userPermissions from existing profile
$userPerms = [regex]::Matches($content, "(?s)<userPermissions>.*?<\/userPermissions>") | ForEach-Object { $_.Value }
$userPermsXml = $userPerms -join "`n"

$fullProfileXml = @"
$header
$userPermsXml
</Profile>
"@

[System.IO.File]::WriteAllText($profilePath, $fullProfileXml, [System.Text.Encoding]::UTF8)
Write-Host "Updated Admin.profile-meta.xml successfully with all FLS and Object permissions."
