for (CronTrigger ct : [SELECT Id FROM CronTrigger]) {
    try {
        System.abortJob(ct.Id);
    } catch (Exception e) {
        System.debug('Error aborting job ' + ct.Id + ': ' + e.getMessage());
    }
}
