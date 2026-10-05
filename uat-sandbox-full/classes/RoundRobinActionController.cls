public with sharing class RoundRobinActionController {

    @AuraEnabled
    public static void assignLeadViaRoundRobin(Id leadId) {
        try {
            if (leadId == null) throw new AuraHandledException('Lead Id is required');

            Lead leadRecord = [
                SELECT Id, OwnerId, Name, Region__c, Projects__c
                FROM Lead 
                WHERE Id = :leadId
                LIMIT 1
            ];

            Id targetQueueId;

            // 1️⃣ Decide the queue
            // switch on leadRecord.Projects__c {
            //     when 'One Bangalore West', 'Kessaku' {
            //         targetQueueId = getQueueIdByName('Bangalore');
            //     }
            //     when 'Kolkata' {
            //         targetQueueId = getQueueIdByName('Kolkata');
            //     }
            // }



            // 1️⃣ Decide the queue
            switch on leadRecord.Projects__c {
                when 'Varthur Vista', 'Yalahanka Yard' {
                    targetQueueId = getQueueIdByName('Bangalore_Queue');
                }
                when 'Banjara Beam','Miyapur Manor' {
                    targetQueueId = getQueueIdByName('Hyderabad_Queue');
                }
                when 'Saket Square','Rohini Rise' {
                    targetQueueId = getQueueIdByName('Delhi_Queue');
                }
            }



            if (targetQueueId == null) { throw new AuraHandledException('Queue not found for assignment.'); }

            // 2️⃣ Get queue members
            Set<Id> userIdsToUse = new Set<Id>();
            for (GroupMember gm : [
                SELECT UserOrGroupId 
                FROM GroupMember 
                WHERE GroupId = :targetQueueId
            ]) {
                if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                    userIdsToUse.add(gm.UserOrGroupId);
                }
            }

            if (userIdsToUse.isEmpty()) { throw new AuraHandledException('Queue has no active direct users.'); }

            // 3️⃣ Assign via Round Robin helper
            RoundRobinAssignHelper.assignLead(leadRecord, userIdsToUse);

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) { ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('RoundRobinActionController').withDescription('Failed to assign lead via round robin. ' + e.getMessage()).withClassName('RoundRobinActionController').withMethodName('assignLeadViaRoundRobin').withErrorType('Assignment Logic').withException(e); ExceptionLogger.logException(payload);
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Id getQueueIdByName(String queueName) {
        try {
            Group g = [
                SELECT Id 
                FROM Group 
                WHERE DeveloperName = :queueName 
                AND Type = 'Queue' 
                LIMIT 1
            ];
            return g.Id;
        } catch (Exception e) {
            return null;
        }
    }
}