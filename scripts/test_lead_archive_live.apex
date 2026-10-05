// Test live lead archive update
Lead ld = [SELECT Id, Name, Archive_For_In_Days__c, Archive_Follow_Up_Date__c, Archive_Populated_Date__c, Archive_Status__c FROM Lead WHERE Id = '00Qbm00000igrD3EAI' LIMIT 1];
System.debug('BEFORE: ' + ld.Name + ' | Days=' + ld.Archive_For_In_Days__c + ' | Status=' + ld.Archive_Status__c);

// 1. Populate Archive_For_In_Days__c = 15
ld.Archive_For_In_Days__c = 15;
update ld;

Lead afterUpdate = [SELECT Id, Name, Archive_For_In_Days__c, Archive_Follow_Up_Date__c, Archive_Populated_Date__c, Archive_Status__c FROM Lead WHERE Id = :ld.Id];
System.debug('AFTER UPDATE (15 Days): Follow-up Date=' + afterUpdate.Archive_Follow_Up_Date__c + ' | Populated Date=' + afterUpdate.Archive_Populated_Date__c + ' | Status=' + afterUpdate.Archive_Status__c);

// 2. Test LWC getArchiveInfo wrapper
LeadArchiveService.LeadArchiveInfo info = LeadArchiveService.getArchiveInfo(ld.Id);
System.debug('LWC WRAPPER: isArchived=' + info.isArchived + ' | isFollowUpDue=' + info.isFollowUpDue + ' | Days=' + info.archiveDays + ' | Follow-up=' + info.followUpDate);

// 3. Dispatch simulated notification
LeadArchiveService.sendFollowUpNotification(ld.Id);
Task t = [SELECT Id, Subject, Priority, Status, Description FROM Task WHERE WhoId = :ld.Id ORDER BY CreatedDate DESC LIMIT 1];
System.debug('CREATED TASK: Subject="' + t.Subject + '" | Priority=' + t.Priority + ' | Description=' + t.Description);
