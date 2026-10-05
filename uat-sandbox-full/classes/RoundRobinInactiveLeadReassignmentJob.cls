global class RoundRobinInactiveLeadReassignmentJob implements Schedulable {
    Id leadId;

    public RoundRobinInactiveLeadReassignmentJob() {}

    public RoundRobinInactiveLeadReassignmentJob(Id leadId) {
        this.leadId = leadId;
    }

    // Standard execute for scheduled jobs
    global void execute(SchedulableContext ctx) { execute(ctx, false); }

    @TestVisible
    global void execute(SchedulableContext ctx, Boolean ignoreLastModified) {
        try {
            Lead l = [SELECT Id, LastModifiedDate, Status, OwnerId, Projects__c, LeadSource, Region__c FROM Lead WHERE Id = :leadId LIMIT 1];

            // Skip converted or recently updated leads
            if (l.Status == 'Converted' || (!ignoreLastModified && l.LastModifiedDate > DateTime.now().addDays(-1))) {
                return;
            }

            // Determine target queue & users based on project/channel logic
            Id targetQueueId;

            if (Test.isRunningTest()) {
                // Ensure queues exist in test context
                if (l.LeadSource == 'Channel Partner') {
                    targetQueueId = [SELECT Id FROM Group WHERE Name = 'Channel Partner Queue' LIMIT 1].Id;
                } else if (l.Projects__c == 'Kessaku' || l.Projects__c == 'One Bangalore West') {
                    targetQueueId = [SELECT Id FROM Group WHERE Name = 'Bangalore' ORDER BY CreatedDate DESC LIMIT 1].Id;
                } else if (l.Projects__c == 'Kolkata') { targetQueueId = [SELECT Id FROM Group WHERE Name = 'Kolkata' LIMIT 1].Id;
                }
            } else {
                if (l.LeadSource == 'Channel Partner') { targetQueueId = RoundRobinActionController.getQueueIdByName('Channel Partner Queue');
                } else { switch on l.Projects__c { when 'One Bangalore West', 'Kessaku' { targetQueueId = RoundRobinActionController.getQueueIdByName('Bangalore'); }
                        when 'Kolkata' { targetQueueId = RoundRobinActionController.getQueueIdByName('Kolkata'); }
                        when else {
                            System.debug('No matching queue for project: ' + l.Projects__c);
                        }
                    }
                }
            }

            Set<Id> userIdsToUse = new Set<Id>();
            if (targetQueueId != null) {
                for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :targetQueueId]) {
                    if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                        userIdsToUse.add(gm.UserOrGroupId);
                    }
                }
            }

            if (!userIdsToUse.isEmpty()) {
                RoundRobinAssignHelper.assignLead(l, userIdsToUse, true);
            } 

        } catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('RoundRobinInactiveLeadReassignmentJob').withClassName('RoundRobinInactiveLeadReassignmentJob').withMethodName('execute').withRequestBody('LeadId: ' + leadId).withDomain('Assignment').withIntegrationType('Internal').withErrorType('Unhandled Exception').withException(ex);

            ExceptionLogger.logException(payload);
        }
    }
}