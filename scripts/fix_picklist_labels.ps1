# scripts/fix_picklist_labels.ps1

$baseDir = "force-app/main/default"

function Fix-PicklistFile($filePath, $fieldLabel, $valueLabels) {
    if (-not (Test-Path $filePath)) { return }
    $content = Get-Content $filePath -Raw
    
    # 1. Fix the top-level <label>
    $content = [regex]::Replace($content, "(<fullName>[^<]+</fullName>\s*(?:<deleteConstraint>[^<]+</deleteConstraint>\s*)?(?:<externalId>[^<]+</externalId>\s*)?)<label>[^<]+</label>", "`$1<label>$fieldLabel</label>")
    
    # 2. Fix the picklist value labels so each matches its fullName
    $content = [regex]::Replace($content, "(?s)<value>\s*<fullName>([^<]+)</fullName>\s*<default>[^<]+</default>\s*<label>[^<]+</label>", "<value>`r`n                <fullName>`$1</fullName>`r`n                <default>false</default>`r`n                <label>`$1</label>")
    
    [System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
    Write-Host "Fixed picklist field: $filePath"
}

# Fix all picklist fields:
Fix-PicklistFile "$baseDir/objects/Project__c/fields/Status__c.field-meta.xml" "Project Status"
Fix-PicklistFile "$baseDir/objects/Tower__c/fields/Construction_Status__c.field-meta.xml" "Construction Status"
Fix-PicklistFile "$baseDir/objects/Unit__c/fields/Configuration__c.field-meta.xml" "Unit Configuration"
Fix-PicklistFile "$baseDir/objects/Unit__c/fields/Status__c.field-meta.xml" "Unit Status"
Fix-PicklistFile "$baseDir/objects/Site_Visit__c/fields/Status__c.field-meta.xml" "Visit Status"
Fix-PicklistFile "$baseDir/objects/Site_Visit__c/fields/Rating__c.field-meta.xml" "Visitor Rating"
Fix-PicklistFile "$baseDir/objects/Payment_Plan__c/fields/Plan_Type__c.field-meta.xml" "Plan Type"
Fix-PicklistFile "$baseDir/objects/Payment_Milestone__c/fields/Trigger_Event__c.field-meta.xml" "Construction Trigger Event"
Fix-PicklistFile "$baseDir/objects/Booking__c/fields/Status__c.field-meta.xml" "Booking Status"
Fix-PicklistFile "$baseDir/objects/Booking_Applicant__c/fields/Applicant_Role__c.field-meta.xml" "Applicant Role"
Fix-PicklistFile "$baseDir/objects/Booking_Applicant__c/fields/KYC_Status__c.field-meta.xml" "KYC Verification Status"
Fix-PicklistFile "$baseDir/objects/Installment__c/fields/Status__c.field-meta.xml" "Installment Status"
Fix-PicklistFile "$baseDir/objects/Receipt__c/fields/Payment_Mode__c.field-meta.xml" "Payment Mode"
Fix-PicklistFile "$baseDir/objects/Receipt__c/fields/Status__c.field-meta.xml" "Receipt Status"
Fix-PicklistFile "$baseDir/objects/Cancellation_Request__c/fields/Reason__c.field-meta.xml" "Cancellation Reason"
Fix-PicklistFile "$baseDir/objects/Cancellation_Request__c/fields/Status__c.field-meta.xml" "Cancellation Status"
Fix-PicklistFile "$baseDir/objects/Lead/fields/Budget_Range__c.field-meta.xml" "Budget Range"
Fix-PicklistFile "$baseDir/objects/Lead/fields/Configuration_Interested__c.field-meta.xml" "Configuration Interested"

Write-Host "All picklist field labels restored and corrected."
