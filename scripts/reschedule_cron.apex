String cronExp = '0 0 1 * * ?'; // Daily at 1:00 AM
try {
    System.schedule('Daily Lead Archive Follow-up Check', cronExp, new LeadArchiveFollowUpSchedulable());
} catch (Exception e) {
    System.debug('Scheduling error: ' + e.getMessage());
}
