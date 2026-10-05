$objs = @('Booking__c', 'Handover__c', 'Inspection__c', 'Inspection_Checklist_Item__c', 'Snag__c', 'Handover_Event_Log__c')
$xml = [System.Collections.Generic.List[string]]::new()
$xml.Add('<?xml version="1.0" encoding="UTF-8"?>')
$xml.Add('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">')
$xml.Add('    <description>Full Admin and Execution permissions across Handover, Inspection, and Snag Management</description>')
$xml.Add('    <hasActivationRequired>false</hasActivationRequired>')
$xml.Add('    <label>Handover Administrator</label>')

foreach ($obj in $objs) {
    $xml.Add('    <objectPermissions>')
    $xml.Add('        <allowCreate>true</allowCreate>')
    $xml.Add('        <allowDelete>true</allowDelete>')
    $xml.Add('        <allowEdit>true</allowEdit>')
    $xml.Add('        <allowRead>true</allowRead>')
    $xml.Add('        <modifyAllRecords>true</modifyAllRecords>')
    $xml.Add("        <object>$obj</object>")
    $xml.Add('        <viewAllRecords>true</viewAllRecords>')
    $xml.Add('    </objectPermissions>')
}

$xml.Add('    <tabSettings>')
$xml.Add('        <tab>Handover__c</tab>')
$xml.Add('        <visibility>Visible</visibility>')
$xml.Add('    </tabSettings>')

$fieldObjs = @('Handover__c', 'Inspection__c', 'Inspection_Checklist_Item__c', 'Snag__c', 'Handover_Event_Log__c')
foreach ($obj in $fieldObjs) {
    $fieldsDir = "force-app/main/default/objects/$obj/fields"
    if (Test-Path $fieldsDir) {
        $files = Get-ChildItem -Path $fieldsDir -Filter "*.field-meta.xml"
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw
            $fName = $f.BaseName.Replace('.field-meta', '')
            $isFormula = $content -match '<formula>'
            $isSummary = $content -match '<summaryOperation>' -or $content -match '<type>Summary</type>'
            $isMasterDetail = $content -match '<type>MasterDetail</type>'
            $isRequired = $content -match '<required>true</required>'
            if ($isMasterDetail -or $isRequired) {
                continue
            }
            $isAutoNumber = $content -match '<type>AutoNumber</type>'
            $editable = 'true'
            if ($isFormula -or $isSummary -or $isAutoNumber) {
                $editable = 'false'
            }
            $xml.Add('    <fieldPermissions>')
            $xml.Add("        <editable>$editable</editable>")
            $xml.Add("        <field>$obj.$fName</field>")
            $xml.Add('        <readable>true</readable>')
            $xml.Add('    </fieldPermissions>')
        }
    }
}
$xml.Add('</PermissionSet>')
[System.IO.File]::WriteAllLines('force-app/main/default/permissionsets/Handover_Administrator.permissionset-meta.xml', $xml)
Write-Host "Created Handover_Administrator.permissionset-meta.xml with line count: $($xml.Count)"
