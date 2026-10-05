public with sharing class SAPChannelPartnerUpdateHandler {

    @future(callout=true)
    public static void sendChannelPartnerUpdateAsync(List<Id> accountIds) {
        if (!Test.isRunningTest()) {
            if (!IntegrationToggle.isEnabled('Residential', 'Update Broker', 'SAP')) {
                return;
            }
        }
        
        if (accountIds != null && !accountIds.isEmpty()) {
            System.enqueueJob(new SAPChannelPartnerUpdateQueueable(accountIds));
        } else {
            System.debug('No Account IDs provided for Channel Partner Update.');
        }
    }
}