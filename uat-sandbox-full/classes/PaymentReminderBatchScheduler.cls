public class PaymentReminderBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new PaymentReminderBatch(), 200);
    }
}