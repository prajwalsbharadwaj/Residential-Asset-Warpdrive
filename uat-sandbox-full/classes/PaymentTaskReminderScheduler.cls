global class PaymentTaskReminderScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        PaymentTaskReminderProcessor.runProcess();
    }
}