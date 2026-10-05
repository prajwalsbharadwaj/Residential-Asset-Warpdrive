SiteVisitController.LeadDetailWrapper d = SiteVisitController.getLeadDetails('00Qbm00000rauErEAI');
System.debug('=== VERIFY LEAD DETAILS ===');
System.debug('Name: ' + d.name);
System.debug('Has Site Visit: ' + d.hasSiteVisit);
System.debug('Site Visit Count: ' + d.siteVisitCount);
System.debug('Recent Visits Count: ' + d.recentVisits.size());
for (SiteVisitController.SiteVisitItemWrapper v : d.recentVisits) {
    System.debug(' - ' + v.name + ' | ' + v.projectName + ' | ' + v.unitName + ' | ' + v.rating + ' | OTP=' + v.otpVerified);
}
