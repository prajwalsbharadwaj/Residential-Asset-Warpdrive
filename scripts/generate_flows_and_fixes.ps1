# scripts/generate_flows_and_fixes.ps1

$baseDir = "force-app/main/default"

function Write-Utf8File($path, $content) {
    $parent = Split-Path $path
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
}

# -------------------------------------------------------------
# 1. FIX Residential_Sales.businessProcess-meta.xml
# -------------------------------------------------------------
Write-Utf8File "$baseDir/objects/Opportunity/businessProcesses/Residential_Sales.businessProcess-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<BusinessProcess xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Residential_Sales</fullName>
    <description>Sales process for residential real estate deal progression</description>
    <isActive>true</isActive>
    <values>
        <fullName>New</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>SV Scheduled</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>In Progress</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>SV Done</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>Qualified</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>Application In Progress</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>Booking Form in Approval</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>Booking Form Approved</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>Closed Won</fullName>
        <default>false</default>
    </values>
    <values>
        <fullName>Closed Lost</fullName>
        <default>false</default>
    </values>
</BusinessProcess>
"@

# -------------------------------------------------------------
# 2. FIX Residential_Sales_CRM.app-meta.xml
# -------------------------------------------------------------
Write-Utf8File "$baseDir/applications/Residential_Sales_CRM.app-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomApplication xmlns="http://soap.sforce.com/2006/04/metadata">
    <brand>
        <headerColor>#0B5CAB</headerColor>
        <shouldOverrideOrgTheme>false</shouldOverrideOrgTheme>
    </brand>
    <description>Dedicated Lightning App for Residential Real Estate Sales, Inventory, Bookings and Collections</description>
    <formFactors>Large</formFactors>
    <formFactors>Small</formFactors>
    <isNavAutoTempTabsDisabled>false</isNavAutoTempTabsDisabled>
    <isNavPersonalizationDisabled>false</isNavPersonalizationDisabled>
    <isNavTabPersistenceDisabled>false</isNavTabPersistenceDisabled>
    <label>Residential Sales CRM</label>
    <navType>Standard</navType>
    <tabs>standard-home</tabs>
    <tabs>standard-Lead</tabs>
    <tabs>standard-Account</tabs>
    <tabs>standard-Contact</tabs>
    <tabs>standard-Opportunity</tabs>
    <tabs>Site_Visit__c</tabs>
    <tabs>Project__c</tabs>
    <tabs>Tower__c</tabs>
    <tabs>Floor__c</tabs>
    <tabs>Unit__c</tabs>
    <tabs>Booking__c</tabs>
    <tabs>Payment_Plan__c</tabs>
    <tabs>Installment__c</tabs>
    <tabs>Receipt__c</tabs>
    <tabs>Cancellation_Request__c</tabs>
    <uiType>Lightning</uiType>
</CustomApplication>
"@

# -------------------------------------------------------------
# 3. FIX LAYOUTS (Required Name fields, Readonly Formula)
# -------------------------------------------------------------
function New-SimpleLayoutFixed($objectLabel, $fieldsLeft, $fieldsRight, $reqName = $false) {
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
    <showEmailCheckbox>false</showEmailCheckbox>
    <showHighlightsPanel>false</showHighlightsPanel>
    <showInteractionLogPanel>false</showInteractionLogPanel>
    <showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>
    <showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>
"@
}

Write-Utf8File "$baseDir/layouts/Project__c-Project Layout.layout-meta.xml" (New-SimpleLayoutFixed "Project" @("Name", "Location__c", "Status__c") @("RERA_Registration_Number__c", "Total_Towers__c", "Description__c") $true)
Write-Utf8File "$baseDir/layouts/Tower__c-Tower Layout.layout-meta.xml" (New-SimpleLayoutFixed "Tower" @("Name", "Project__c") @("Construction_Status__c", "Total_Floors__c") $true)
Write-Utf8File "$baseDir/layouts/Floor__c-Floor Layout.layout-meta.xml" (New-SimpleLayoutFixed "Floor" @("Name", "Tower__c") @("Floor_Number__c", "Units_Per_Floor__c") $true)
Write-Utf8File "$baseDir/layouts/Unit__c-Unit Layout.layout-meta.xml" (New-SimpleLayoutFixed "Unit" @("Name", "Floor__c", "Configuration__c", "Status__c") @("Carpet_Area_SqFt__c", "Super_Built_Up_Area_SqFt__c", "Base_Price__c", "Total_Price__c", "SAP_Material_Code__c") $true)
Write-Utf8File "$baseDir/layouts/Payment_Plan__c-Payment Plan Layout.layout-meta.xml" (New-SimpleLayoutFixed "Payment Plan" @("Name", "Project__c", "Plan_Type__c") @("Active__c", "Description__c") $true)
Write-Utf8File "$baseDir/layouts/Payment_Milestone__c-Payment Milestone Layout.layout-meta.xml" (New-SimpleLayoutFixed "Payment Milestone" @("Name", "Payment_Plan__c", "Milestone_Order__c") @("Milestone_Percentage__c", "Trigger_Event__c", "Days_From_Booking__c") $true)
Write-Utf8File "$baseDir/layouts/Booking__c-Booking Layout.layout-meta.xml" (New-SimpleLayoutFixed "Booking" @("Opportunity__c", "Customer__c", "Unit__c", "Payment_Plan__c", "Booking_Date__c") @("Total_Booking_Amount__c", "Status__c", "SAP_Customer_Code__c", "Tower_Incharge__c") $false)
Write-Utf8File "$baseDir/layouts/Installment__c-Installment Layout.layout-meta.xml" (New-SimpleLayoutFixed "Installment" @("Booking__c", "Payment_Milestone__c", "Due_Date__c", "Status__c") @("Amount__c", "Paid_Amount__c", "Outstanding_Amount__c", "Overdue_Interest__c", "Days_Overdue__c", "Interest_Waived__c") $false)
Write-Utf8File "$baseDir/layouts/Receipt__c-Receipt Layout.layout-meta.xml" (New-SimpleLayoutFixed "Receipt" @("Installment__c", "Receipt_Date__c", "Amount__c") @("Payment_Mode__c", "Transaction_Reference__c", "Status__c", "Reconciliation_Notes__c") $false)

# -------------------------------------------------------------
# 4. FIX PERMISSION SETS (Dependencies & Application Visibility)
# -------------------------------------------------------------
function New-PermSetFull($label, $desc, $objs, $tabs) {
    $objXml = ($objs | ForEach-Object {
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

    $tabXml = ($tabs | ForEach-Object {
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

# Sales Exec Demo
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
Write-Utf8File "$baseDir/permissionsets/Sales_Exec_Demo.permissionset-meta.xml" (New-PermSetFull "Sales Exec Demo" "Sales Executive access for Lead, Opportunity, Quote, Site Visits and Inventory" $salesObjs $salesTabs)

# CRM Team Demo
$crmObjs = @(
    @{ obj="Project__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Tower__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Floor__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Unit__c"; r="true"; c="false"; e="true"; d="false" },
    @{ obj="Payment_Plan__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Payment_Milestone__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Booking__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Booking_Applicant__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Installment__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Receipt__c"; r="true"; c="true"; e="true"; d="false" }
)
$crmTabs = @("Booking__c", "Booking_Applicant__c", "Installment__c", "Receipt__c", "Unit__c", "Payment_Plan__c")
Write-Utf8File "$baseDir/permissionsets/CRM_Team_Demo.permissionset-meta.xml" (New-PermSetFull "CRM Team Demo" "CRM Team access for Bookings, Applicants, Installments, Receipts" $crmObjs $crmTabs)

# Finance Demo
$finObjs = @(
    @{ obj="Project__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Tower__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Floor__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Unit__c"; r="true"; c="false"; e="false"; d="false" },
    @{ obj="Booking__c"; r="true"; c="false"; e="true"; d="false" },
    @{ obj="Installment__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Receipt__c"; r="true"; c="true"; e="true"; d="false" },
    @{ obj="Cancellation_Request__c"; r="true"; c="true"; e="true"; d="false" }
)
$finTabs = @("Receipt__c", "Cancellation_Request__c", "Installment__c", "Booking__c")
Write-Utf8File "$baseDir/permissionsets/Finance_Demo.permissionset-meta.xml" (New-PermSetFull "Finance Demo" "Finance team access to approve and reconcile Receipts and Cancellation Requests" $finObjs $finTabs)

# -------------------------------------------------------------
# 5. FLOW 1: Opportunity_Closed_Won_Booking (Record-Triggered)
# -------------------------------------------------------------
Write-Utf8File "$baseDir/flows/Opportunity_Closed_Won_Booking.flow-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>67.0</apiVersion>
    <description>When Opportunity reaches Closed Won, auto-create Booking__c and update Unit__c status to Sold</description>
    <environments>Default</environments>
    <interviewLabel>Opportunity Closed Won Booking {!`$Flow.CurrentDateTime}</interviewLabel>
    <label>Opportunity Closed Won Booking</label>
    <processMetadataValues>
        <name>BuilderType</name>
        <value>
            <stringValue>LightningFlowBuilder</stringValue>
        </value>
    </processMetadataValues>
    <processType>AutoLaunchedFlow</processType>
    <recordCreates>
        <name>Create_Booking_Record</name>
        <label>Create Booking Record</label>
        <locationX>176</locationX>
        <locationY>323</locationY>
        <connector>
            <targetReference>Update_Unit_Status_Sold</targetReference>
        </connector>
        <inputAssignments>
            <field>Booking_Date__c</field>
            <value>
                <elementReference>`$Flow.CurrentDate</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Customer__c</field>
            <value>
                <elementReference>`$Record.AccountId</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Opportunity__c</field>
            <value>
                <elementReference>`$Record.Id</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Status__c</field>
            <value>
                <stringValue>New</stringValue>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Total_Booking_Amount__c</field>
            <value>
                <elementReference>`$Record.Amount</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Unit__c</field>
            <value>
                <elementReference>`$Record.Tagged_Unit__c</elementReference>
            </value>
        </inputAssignments>
        <object>Booking__c</object>
        <storeOutputAutomatically>true</storeOutputAutomatically>
    </recordCreates>
    <recordUpdates>
        <name>Update_Unit_Status_Sold</name>
        <label>Update Unit Status to Sold</label>
        <locationX>176</locationX>
        <locationY>431</locationY>
        <filterLogic>and</filterLogic>
        <filters>
            <field>Id</field>
            <operator>EqualTo</operator>
            <value>
                <elementReference>`$Record.Tagged_Unit__c</elementReference>
            </value>
        </filters>
        <inputAssignments>
            <field>Status__c</field>
            <value>
                <stringValue>Sold</stringValue>
            </value>
        </inputAssignments>
        <object>Unit__c</object>
    </recordUpdates>
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector>
            <targetReference>Create_Booking_Record</targetReference>
        </connector>
        <doesRequireRecordChangedToMeetCriteria>true</doesRequireRecordChangedToMeetCriteria>
        <filterLogic>and</filterLogic>
        <filters>
            <field>StageName</field>
            <operator>EqualTo</operator>
            <value>
                <stringValue>Closed Won</stringValue>
            </value>
        </filters>
        <filters>
            <field>Tagged_Unit__c</field>
            <operator>IsNull</operator>
            <value>
                <booleanValue>false</booleanValue>
            </value>
        </filters>
        <object>Opportunity</object>
        <recordTriggerType>CreateAndUpdate</recordTriggerType>
        <triggerType>RecordAfterSave</triggerType>
    </start>
    <status>Active</status>
</Flow>
"@

# -------------------------------------------------------------
# 6. FLOW 2: Installment_Calculate_Overdue_Interest (Record-Triggered)
# -------------------------------------------------------------
Write-Utf8File "$baseDir/flows/Installment_Calculate_Overdue_Interest.flow-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>67.0</apiVersion>
    <description>Calculates 18% p.a. simple interest on overdue installment when status is Due and Due Date has passed</description>
    <environments>Default</environments>
    <formulas>
        <name>DaysOverdueCalc</name>
        <dataType>Number</dataType>
        <expression>{!`$Flow.CurrentDate} - {!`$Record.Due_Date__c}</expression>
        <scale>0</scale>
    </formulas>
    <formulas>
        <name>OverdueInterestCalc</name>
        <dataType>Currency</dataType>
        <expression>{!`$Record.Outstanding_Amount__c} * 0.18 * (({!`$Flow.CurrentDate} - {!`$Record.Due_Date__c}) / 365.0)</expression>
        <scale>2</scale>
    </formulas>
    <interviewLabel>Installment Calculate Overdue Interest {!`$Flow.CurrentDateTime}</interviewLabel>
    <label>Installment Calculate Overdue Interest</label>
    <processMetadataValues>
        <name>BuilderType</name>
        <value>
            <stringValue>LightningFlowBuilder</stringValue>
        </value>
    </processMetadataValues>
    <processType>AutoLaunchedFlow</processType>
    <recordUpdates>
        <name>Update_Installment_Overdue_Interest</name>
        <label>Update Overdue Interest</label>
        <locationX>176</locationX>
        <locationY>323</locationY>
        <inputAssignments>
            <field>Days_Overdue__c</field>
            <value>
                <elementReference>DaysOverdueCalc</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Overdue_Interest__c</field>
            <value>
                <elementReference>OverdueInterestCalc</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Status__c</field>
            <value>
                <stringValue>Overdue</stringValue>
            </value>
        </inputAssignments>
        <inputReference>`$Record</inputReference>
    </recordUpdates>
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector>
            <targetReference>Update_Installment_Overdue_Interest</targetReference>
        </connector>
        <filterLogic>and</filterLogic>
        <filters>
            <field>Status__c</field>
            <operator>EqualTo</operator>
            <value>
                <stringValue>Due</stringValue>
            </value>
        </filters>
        <filters>
            <field>Due_Date__c</field>
            <operator>LessThan</operator>
            <value>
                <elementReference>`$Flow.CurrentDate</elementReference>
            </value>
        </filters>
        <filters>
            <field>Interest_Waived__c</field>
            <operator>EqualTo</operator>
            <value>
                <booleanValue>false</booleanValue>
            </value>
        </filters>
        <object>Installment__c</object>
        <recordTriggerType>CreateAndUpdate</recordTriggerType>
        <triggerType>RecordAfterSave</triggerType>
    </start>
    <status>Active</status>
</Flow>
"@

# -------------------------------------------------------------
# 7. FLOW 3: Log_Receipt (Screen Flow)
# -------------------------------------------------------------
Write-Utf8File "$baseDir/flows/Log_Receipt.flow-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>67.0</apiVersion>
    <choices>
        <name>Choice_Cheque</name>
        <choiceText>Cheque</choiceText>
        <dataType>String</dataType>
        <value>
            <stringValue>Cheque</stringValue>
        </value>
    </choices>
    <choices>
        <name>Choice_CreditCard</name>
        <choiceText>Credit Card</choiceText>
        <dataType>String</dataType>
        <value>
            <stringValue>Credit Card</stringValue>
        </value>
    </choices>
    <choices>
        <name>Choice_DemandDraft</name>
        <choiceText>Demand Draft</choiceText>
        <dataType>String</dataType>
        <value>
            <stringValue>Demand Draft</stringValue>
        </value>
    </choices>
    <choices>
        <name>Choice_NEFT_RTGS</name>
        <choiceText>NEFT/RTGS</choiceText>
        <dataType>String</dataType>
        <value>
            <stringValue>NEFT/RTGS</stringValue>
        </value>
    </choices>
    <choices>
        <name>Choice_UPI</name>
        <choiceText>UPI</choiceText>
        <dataType>String</dataType>
        <value>
            <stringValue>UPI</stringValue>
        </value>
    </choices>
    <description>Quick guided entry for logging a payment receipt against an installment</description>
    <environments>Default</environments>
    <interviewLabel>Log Receipt {!`$Flow.CurrentDateTime}</interviewLabel>
    <label>Log Receipt</label>
    <processMetadataValues>
        <name>BuilderType</name>
        <value>
            <stringValue>LightningFlowBuilder</stringValue>
        </value>
    </processMetadataValues>
    <processType>Flow</processType>
    <recordCreates>
        <name>Create_Receipt_Record</name>
        <label>Create Receipt Record</label>
        <locationX>176</locationX>
        <locationY>350</locationY>
        <connector>
            <targetReference>Confirmation_Screen</targetReference>
        </connector>
        <inputAssignments>
            <field>Amount__c</field>
            <value>
                <elementReference>Payment_Amount</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Installment__c</field>
            <value>
                <elementReference>recordId</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Payment_Mode__c</field>
            <value>
                <elementReference>Payment_Mode</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Receipt_Date__c</field>
            <value>
                <elementReference>Receipt_Date</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Reconciliation_Notes__c</field>
            <value>
                <elementReference>Reconciliation_Notes</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Status__c</field>
            <value>
                <stringValue>Pending Reconciliation</stringValue>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Transaction_Reference__c</field>
            <value>
                <elementReference>Transaction_Reference</elementReference>
            </value>
        </inputAssignments>
        <object>Receipt__c</object>
        <storeOutputAutomatically>true</storeOutputAutomatically>
    </recordCreates>
    <recordLookups>
        <name>Get_Installment_Details</name>
        <label>Get Installment Details</label>
        <locationX>176</locationX>
        <locationY>134</locationY>
        <assignNullValuesIfNoRecordsFound>false</assignNullValuesIfNoRecordsFound>
        <connector>
            <targetReference>Receipt_Entry_Screen</targetReference>
        </connector>
        <filterLogic>and</filterLogic>
        <filters>
            <field>Id</field>
            <operator>EqualTo</operator>
            <value>
                <elementReference>recordId</elementReference>
            </value>
        </filters>
        <getFirstRecordOnly>true</getFirstRecordOnly>
        <object>Installment__c</object>
        <storeOutputAutomatically>true</storeOutputAutomatically>
    </recordLookups>
    <screens>
        <name>Confirmation_Screen</name>
        <label>Receipt Logged</label>
        <locationX>176</locationX>
        <locationY>458</locationY>
        <allowBack>false</allowBack>
        <allowFinish>true</allowFinish>
        <allowPause>false</allowPause>
        <fields>
            <name>Success_Message</name>
            <fieldText>&lt;p&gt;&lt;strong style=&quot;color: rgb(15, 128, 23); font-size: 16px;&quot;&gt;Receipt Created Successfully!&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;&lt;br&gt;&lt;/p&gt;&lt;p&gt;A payment receipt for &lt;strong&gt;₹ {!Payment_Amount}&lt;/strong&gt; has been recorded against installment &lt;strong&gt;{!Get_Installment_Details.Name}&lt;/strong&gt;.&lt;/p&gt;&lt;p&gt;&lt;br&gt;&lt;/p&gt;&lt;p&gt;&lt;b&gt;Current Status:&lt;/b&gt; &lt;span style=&quot;color: rgb(235, 137, 8);&quot;&gt;Pending Reconciliation&lt;/span&gt;&lt;/p&gt;&lt;p&gt;The receipt is now ready for Finance team approval and SAP bank clearance.&lt;/p&gt;</fieldText>
            <fieldType>DisplayText</fieldType>
        </fields>
        <showFooter>true</showFooter>
        <showHeader>true</showHeader>
    </screens>
    <screens>
        <name>Receipt_Entry_Screen</name>
        <label>Log Payment Receipt</label>
        <locationX>176</locationX>
        <locationY>242</locationY>
        <allowBack>false</allowBack>
        <allowFinish>true</allowFinish>
        <allowPause>false</allowPause>
        <connector>
            <targetReference>Create_Receipt_Record</targetReference>
        </connector>
        <fields>
            <name>Installment_Summary</name>
            <fieldText>&lt;p&gt;&lt;strong style=&quot;font-size: 14px;&quot;&gt;Installment Information&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;&lt;b&gt;Installment:&lt;/b&gt; {!Get_Installment_Details.Name}&lt;/p&gt;&lt;p&gt;&lt;b&gt;Due Date:&lt;/b&gt; {!Get_Installment_Details.Due_Date__c}&lt;/p&gt;&lt;p&gt;&lt;b&gt;Outstanding Amount:&lt;/b&gt; ₹ {!Get_Installment_Details.Outstanding_Amount__c}&lt;/p&gt;</fieldText>
            <fieldType>DisplayText</fieldType>
        </fields>
        <fields>
            <name>Payment_Amount</name>
            <dataType>Currency</dataType>
            <defaultValue>
                <elementReference>Get_Installment_Details.Outstanding_Amount__c</elementReference>
            </defaultValue>
            <fieldText>Payment Amount (₹)</fieldText>
            <fieldType>InputField</fieldType>
            <isRequired>true</isRequired>
            <scale>2</scale>
        </fields>
        <fields>
            <name>Receipt_Date</name>
            <dataType>Date</dataType>
            <defaultValue>
                <elementReference>`$Flow.CurrentDate</elementReference>
            </defaultValue>
            <fieldText>Receipt Date</fieldText>
            <fieldType>InputField</fieldType>
            <isRequired>true</isRequired>
        </fields>
        <fields>
            <name>Payment_Mode</name>
            <choiceReferences>Choice_NEFT_RTGS</choiceReferences>
            <choiceReferences>Choice_UPI</choiceReferences>
            <choiceReferences>Choice_Cheque</choiceReferences>
            <choiceReferences>Choice_DemandDraft</choiceReferences>
            <choiceReferences>Choice_CreditCard</choiceReferences>
            <dataType>String</dataType>
            <defaultSelectedChoiceReference>Choice_NEFT_RTGS</defaultSelectedChoiceReference>
            <fieldText>Payment Mode</fieldText>
            <fieldType>DropdownBox</fieldType>
            <isRequired>true</isRequired>
        </fields>
        <fields>
            <name>Transaction_Reference</name>
            <dataType>String</dataType>
            <fieldText>Transaction / Cheque / UTR Number</fieldText>
            <fieldType>InputField</fieldType>
            <isRequired>true</isRequired>
        </fields>
        <fields>
            <name>Reconciliation_Notes</name>
            <fieldText>Reconciliation Notes</fieldText>
            <fieldType>LargeTextArea</fieldType>
            <isRequired>false</isRequired>
        </fields>
        <showFooter>true</showFooter>
        <showHeader>true</showHeader>
    </screens>
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector>
            <targetReference>Get_Installment_Details</targetReference>
        </connector>
    </start>
    <status>Active</status>
    <variables>
        <name>recordId</name>
        <dataType>String</dataType>
        <isCollection>false</isCollection>
        <isInput>true</isInput>
        <isOutput>false</isOutput>
    </variables>
</Flow>
"@

# -------------------------------------------------------------
# 8. APPROVAL PROCESS on Receipt__c
# -------------------------------------------------------------
Write-Utf8File "$baseDir/approvalProcesses/Receipt__c.Receipt_Approval_Process.approvalProcess-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<ApprovalProcess xmlns="http://soap.sforce.com/2006/04/metadata">
    <active>true</active>
    <allowRecall>true</allowRecall>
    <allowedSubmitters>
        <type>owner</type>
    </allowedSubmitters>
    <approvalPageFields>
        <field>Name</field>
        <field>Installment__c</field>
        <field>Amount__c</field>
        <field>Payment_Mode__c</field>
        <field>Receipt_Date__c</field>
        <field>Transaction_Reference__c</field>
        <field>Status__c</field>
    </approvalPageFields>
    <approvalStep>
        <allowDelegate>false</allowDelegate>
        <assignedApprover>
            <approver>
                <type>userHierarchyField</type>
            </approver>
        </assignedApprover>
        <entryCriteria>
            <criteriaItems>
                <field>Receipt__c.Status__c</field>
                <operation>equals</operation>
                <value>Pending Reconciliation</value>
            </criteriaItems>
        </entryCriteria>
        <label>Finance Verification</label>
        <name>Finance_Verification</name>
    </approvalStep>
    <description>Approval Process for Finance team to confirm payment receipt against bank records</description>
    <entryCriteria>
        <criteriaItems>
            <field>Receipt__c.Status__c</field>
            <operation>equals</operation>
            <value>Pending Reconciliation</value>
        </criteriaItems>
    </entryCriteria>
    <finalApprovalActions>
        <action>
            <name>Set_Status_Confirmed</name>
            <type>FieldUpdate</type>
        </action>
    </finalApprovalActions>
    <finalApprovalRecordLock>false</finalApprovalRecordLock>
    <finalRejectionActions>
        <action>
            <name>Set_Status_Rejected</name>
            <type>FieldUpdate</type>
        </action>
    </finalRejectionActions>
    <finalRejectionRecordLock>false</finalRejectionRecordLock>
    <initialSubmissionActions>
        <action>
            <name>Lock_Receipt_Record</name>
            <type>FieldUpdate</type>
        </action>
    </initialSubmissionActions>
    <label>Receipt Approval Process</label>
    <recordEditability>AdminOnly</recordEditability>
    <showApprovalHistory>true</showApprovalHistory>
</ApprovalProcess>
"@

# Field Updates for Approval Process
Write-Utf8File "$baseDir/workflows/Receipt__c.workflow-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>Set_Status_Confirmed</fullName>
        <description>Sets Receipt Status to Confirmed upon Finance approval</description>
        <field>Status__c</field>
        <literalValue>Confirmed</literalValue>
        <name>Set Status Confirmed</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
        <reevaluateOnChange>false</reevaluateOnChange>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Set_Status_Rejected</fullName>
        <description>Sets Receipt Status to Rejected upon Finance rejection</description>
        <field>Status__c</field>
        <literalValue>Rejected</literalValue>
        <name>Set Status Rejected</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
        <reevaluateOnChange>false</reevaluateOnChange>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Lock_Receipt_Record</fullName>
        <description>Maintains status as Pending Reconciliation while awaiting review</description>
        <field>Status__c</field>
        <literalValue>Pending Reconciliation</literalValue>
        <name>Lock Receipt Record</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
        <reevaluateOnChange>false</reevaluateOnChange>
    </fieldUpdates>
</Workflow>
"@

# Quick action for Screen Flow on Installment__c
Write-Utf8File "$baseDir/quickActions/Installment__c.Log_Receipt.quickAction-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<QuickAction xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Guided quick action to log a payment receipt against this installment</description>
    <flowDefinition>Log_Receipt</flowDefinition>
    <label>Log Receipt</label>
    <optionsCreateFeedItem>false</optionsCreateFeedItem>
    <type>Flow</type>
</QuickAction>
"@

Write-Host "Flows, Approval Process, Workflows, Quick Actions and fixes generated."
