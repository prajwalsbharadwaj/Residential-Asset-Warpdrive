List<CronTrigger> existing = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Lead Archive Follow-Up Daily Job'];
if (existing.isEmpty()) {
    System.schedule('Lead Archive Follow-Up Daily Job', '0 0 8 * * ?', new LeadArchiveFollowUpSchedulable());
    System.debug('=== Scheduled Lead Archive Follow-Up Daily Job at 8:00 AM Daily ===');
} else {
    System.debug('=== Lead Archive Follow-Up Daily Job is already scheduled ===');
}
