String jobName = 'Daily Lead Archive Follow-up Check';
String cron = '0 0 8 * * ?'; // Every day at 8:00 AM
try {
    System.schedule(jobName, cron, new LeadArchiveFollowUpSchedulable());
    System.debug('Scheduled ' + jobName + ' successfully.');
} catch (Exception e) {
    System.debug('Note: ' + e.getMessage());
}
