public class PaymentTaskReminderProcessor {

    // ============================================================
    // ===============  MAIN ENTRY POINT FOR SCHEDULER  ============
    // ============================================================
    public static void runProcess() {

        Date reminderTriggerDate = Date.today().addDays(15);
        Date yesterday = Date.today().addDays(-1);
        Date tomorrow = Date.today().addDays(1);

        // ---- GET BOOKING PAYMENT SCHEDULES ----
        List<Booking_Payment_Schedule__c> schedules = [
            SELECT Id,
                   Installment_Amount__c,
                   Payment_Due_Date__c,
                   Booking__c,
                   Booking__r.OwnerId,
                   Booking__r.Owner.Email,
                   Booking__r.Owner.FirstName,
                   Booking__r.Account_Id__r.Name,
                   Booking__r.Unit_Id__r.Name
            FROM Booking_Payment_Schedule__c
            WHERE Payment_Due_Date__c = :reminderTriggerDate
        ];

        // ============================================================
        // ================ PROCESS PAYMENT REMINDERS ==================
        // ============================================================
        for (Booking_Payment_Schedule__c bps : schedules) {

            // ----------------------- EMAIL ----------------------------
            if (String.isNotBlank(bps.Booking__r.Owner.Email)) {

                String emailBody =
                    'Dear ' + bps.Booking__r.Owner.FirstName + ',\n\n' +
                    'This is a reminder to follow up with your assigned customer regarding an upcoming payment due in 15 days.\n\n' +
                    'Payment Details:\n' +
                    'Customer Name: ' + bps.Booking__r.Account_Id__r.Name + '\n' +
                    'Unit: ' + bps.Booking__r.Unit_Id__r.Name + '\n' +
                    'Payment Amount: ' + bps.Installment_Amount__c + '\n' +
                    'Scheduled Payment Date: ' + bps.Payment_Due_Date__c + '\n\n' +
                    'Action Required:\n' +
                    'Contact the customer to remind them about the upcoming payment.\n' +
                    'Log your follow-up actions in the system.\n\n' +
                    'Best regards,\nPhoenix Residential Notifications';

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ bps.Booking__r.Owner.Email });
                mail.setSubject('Reminder: Payment Due in 15 Days – ' + bps.Booking__r.Account_Id__r.Name);
                mail.setPlainTextBody(emailBody);

                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
            }

            // ------------------- CUSTOM NOTIFICATION --------------------
            sendCustomNotification(
                bps.Booking__r.OwnerId,
                bps.Booking__c,   // target record MUST be Booking__c
                'Reminder: Payment Due in 15 Days – ' + bps.Booking__r.Account_Id__r.Name,
                'A payment is due in 15 days for customer ' +
                bps.Booking__r.Account_Id__r.Name +
                ' (' + bps.Booking__r.Unit_Id__r.Name + '). Please contact the customer.',
                'General_Custom_Notification'
            );
        }

        // ============================================================
        // ================ PROCESS TASKS DUE YESTERDAY ===============
        // ============================================================
        List<Task> oldTasks = [
            SELECT Id, Subject, ActivityDate, OwnerId, WhoId
            FROM Task
            WHERE ActivityDate = :yesterday
        ];

        List<Task> tasksToUpdate = new List<Task>();
        List<Task> tasksToInsert = new List<Task>();

        for (Task t : oldTasks) {

            t.put('Missed_Follow_up__c', true);
            tasksToUpdate.add(t);

            Task follow = new Task();
            follow.OwnerId = t.OwnerId;
            follow.WhoId = t.WhoId;
            follow.ActivityDate = tomorrow;
            follow.Status = 'Not Started';
            follow.Priority = 'High';

            String subj = 'Follow Up: Overdue Task for ' + t.Subject;
            if (subj.length() > 255) subj = subj.substring(0, 255);
            follow.Subject = subj;

            follow.Description =
                'This task was created because the original task "' +
                t.Subject + '" (Due: ' + t.ActivityDate +
                ') was overdue and incomplete. Please follow up with the customer.';

            tasksToInsert.add(follow);
        }

        if (!tasksToUpdate.isEmpty()) update tasksToUpdate;
        if (!tasksToInsert.isEmpty()) insert tasksToInsert;
    }


    // ============================================================
    // ============  SEPARATE CUSTOM NOTIFICATION METHOD ==========
    // ============================================================
    private static void sendCustomNotification(
        Id recipientId,
        Id targetRecordId,
        String title,
        String body,
        String notifTypeDeveloperName
    ) {
        try {
            // Fetch Notification Type
            CustomNotificationType notifType = [
                SELECT Id 
                FROM CustomNotificationType
                WHERE DeveloperName = :notifTypeDeveloperName
                LIMIT 1
            ];

            if (notifType != null) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setNotificationTypeId(notifType.Id);
                notification.setTitle(title);
                notification.setBody(body);
                notification.setTargetId(targetRecordId);
                notification.setSenderId(UserInfo.getUserId());

                // This is the method YOUR org supports
                notification.send(new Set<String>{ recipientId });
            }
        } catch (Exception ex) {
            System.debug('Custom Notification Error: ' + ex.getMessage());
        }
    }
}