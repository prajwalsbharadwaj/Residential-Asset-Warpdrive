for(CronTrigger ct : [SELECT Id FROM CronTrigger]) {
    try {
        System.abortJob(ct.Id);
    } catch(Exception e) {
        System.debug('Error aborting cron: ' + e.getMessage());
    }
}
for (AsyncApexJob job : [SELECT Id FROM AsyncApexJob WHERE Status IN ('Queued', 'Holding', 'Preparing', 'Processing')]) {
    try {
        System.abortJob(job.Id);
    } catch(Exception e) {
        System.debug('Error aborting job: ' + e.getMessage());
    }
}
System.debug('All pending cron and async jobs aborted successfully.');
