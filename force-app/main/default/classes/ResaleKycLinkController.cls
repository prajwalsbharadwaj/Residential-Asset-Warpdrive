/**
 * Internal (Opportunity page) controller for the Resale KYC form link.
 * Called by the resaleKycFormAction LWC on the Resale Opportunity record page.
 */
public with sharing class ResaleKycLinkController {

    public class KycStatus {
        @AuraEnabled public String url;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime generatedAt;
        @AuraEnabled public Date expiresOn;
        @AuraEnabled public Boolean expired = false;
        @AuraEnabled public Datetime lastSavedAt;
        @AuraEnabled public Datetime submittedAt;
        @AuraEnabled public String buyerName;
        @AuraEnabled public String buyerEmail;
        @AuraEnabled public String buyerMobile;
        @AuraEnabled public String siteError;
    }

    @AuraEnabled(cacheable=true)
    public static KycStatus getStatus(Id opportunityId) {
        try {
            Opportunity o = load(opportunityId);
            KycStatus s = new KycStatus();
            s.url = o.Booking_Form_URL__c;
            s.status = o.Booking_Form_Status__c;
            s.generatedAt = o.Booking_Form_Generated_At__c;
            s.expiresOn = o.Booking_Form_Expires_On__c;
            s.expired = o.Booking_Form_Expires_On__c != null
                && o.Booking_Form_Expires_On__c < Date.today()
                && o.Booking_Form_Status__c != ResaleKycService.STATUS_SUBMITTED;
            s.lastSavedAt = o.Booking_Form_Last_Saved_At__c;
            s.submittedAt = o.Booking_Form_Submitted_At__c;
            s.buyerName = o.Buyer_Name__c;
            s.buyerEmail = o.Buyer_Email__c;
            s.buyerMobile = o.Buyer_Phone__c;
            return s;
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    /** Generates (or replaces) the KYC form link and sends it to the buyer by email. */
    @AuraEnabled
    public static KycStatus generateAndSendLink(Id opportunityId) {
        try {
            Opportunity o = load(opportunityId);
            if (o.Booking_Form_Status__c == ResaleKycService.STATUS_SUBMITTED) {
                throw new ResaleKycService.ResaleKycException(
                    'The buyer has already submitted this form. Reopen it to allow changes.');
            }
            if (String.isBlank(o.Buyer_Email__c)) {
                throw new ResaleKycService.ResaleKycException(
                    'Buyer Email is required before generating the KYC form link. Add it on the Opportunity.');
            }
            // Build the site base URL from the Network (Experience Cloud community) record.
            // The Network UrlPathPrefix is the actual public URL path for the community.
            // We query the Network object (not Site) because Experience Cloud creates a Site
            // with a 'vforcesite' suffix — the Network holds the canonical path prefix.
            String siteBase;
            List<Network> networks = [
                SELECT Id, UrlPathPrefix FROM Network
                WHERE Name = 'Nikoo Homes Booking' AND Status = 'Live'
                LIMIT 1
            ];
            String pathPrefix = networks.isEmpty() ? 'bookingvforcesite' : networks[0].UrlPathPrefix;
            String orgDomain = URL.getOrgDomainUrl().toExternalForm();
            if (orgDomain.contains('.sandbox.my.salesforce.com')) {
                siteBase = orgDomain.replace('.sandbox.my.salesforce.com', '.sandbox.my.site.com') + '/' + pathPrefix;
            } else if (orgDomain.contains('.my.salesforce.com')) {
                siteBase = orgDomain.replace('.my.salesforce.com', '.my.site.com') + '/' + pathPrefix;
            } else {
                siteBase = orgDomain + '/' + pathPrefix;
            }

            String token = ResaleKycService.newToken();
            String url   = siteBase + ResaleKycService.FORM_PATH + '?token=' + token;
            Date   expiry = Date.today().addDays(ResaleKycService.LINK_VALIDITY_DAYS);

            Opportunity upd = new Opportunity(Id = o.Id);
            upd.Booking_Form_Token__c     = token;
            upd.Booking_Form_URL__c       = url;
            upd.Booking_Form_Status__c    = ResaleKycService.STATUS_GENERATED;
            upd.Booking_Form_Generated_At__c = Datetime.now();
            upd.Booking_Form_Expires_On__c   = expiry;
            upd.Booking_Form_Last_Saved_At__c = null;
            upd.Booking_Form_Submitted_At__c  = null;
            upd.Booking_Form_Data__c          = JSON.serialize(ResaleKycService.prefill(o));
            update upd;

            // Send email to buyer
            sendLinkEmail(o.Buyer_Name__c, o.Buyer_Email__c, url, o.Name, o.Owner.Name);

            // Return updated status
            o.Booking_Form_URL__c = url;
            o.Booking_Form_Status__c = ResaleKycService.STATUS_GENERATED;
            o.Booking_Form_Generated_At__c = Datetime.now();
            o.Booking_Form_Expires_On__c = expiry;
            return buildStatus(o);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    /** Reopens a submitted form so the buyer can make corrections. */
    @AuraEnabled
    public static KycStatus reopenForm(Id opportunityId) {
        try {
            Opportunity o = load(opportunityId);
            Opportunity upd = new Opportunity(Id = o.Id);
            upd.Booking_Form_Status__c   = ResaleKycService.STATUS_GENERATED;
            upd.Booking_Form_Submitted_At__c = null;
            upd.Buyer_KYC_Status__c = 'In Progress';
            update upd;
            o.Booking_Form_Status__c = ResaleKycService.STATUS_GENERATED;
            o.Booking_Form_Submitted_At__c = null;
            return buildStatus(o);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    // ── Private helpers ──

    private static Opportunity load(Id oppId) {
        return [
            SELECT Id, Name, OwnerId, Owner.Name, AccountId,
                Buyer_Name__c, Buyer_Phone__c, Buyer_Email__c, Buyer_Contact__c,
                Booking_Form_Token__c, Booking_Form_URL__c, Booking_Form_Status__c,
                Booking_Form_Step__c, Booking_Form_Data__c, Booking_Form_Expires_On__c,
                Booking_Form_Generated_At__c, Booking_Form_Last_Saved_At__c,
                Booking_Form_Submitted_At__c, Buyer_KYC_Status__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
    }

    private static KycStatus buildStatus(Opportunity o) {
        KycStatus s = new KycStatus();
        s.url = o.Booking_Form_URL__c;
        s.status = o.Booking_Form_Status__c;
        s.generatedAt = o.Booking_Form_Generated_At__c;
        s.expiresOn = o.Booking_Form_Expires_On__c;
        s.expired = false;
        s.lastSavedAt = o.Booking_Form_Last_Saved_At__c;
        s.submittedAt = o.Booking_Form_Submitted_At__c;
        s.buyerName = o.Buyer_Name__c;
        s.buyerEmail = o.Buyer_Email__c;
        s.buyerMobile = o.Buyer_Phone__c;
        return s;
    }

    private static void sendLinkEmail(String buyerName, String buyerEmail, String url, String oppName, String rmName) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ buyerEmail });
        mail.setSubject('Your Resale KYC & Booking Form – ' + oppName);
        mail.setHtmlBody(
            '<p>Dear ' + (String.isNotBlank(buyerName) ? buyerName : 'Buyer') + ',</p>'
            + '<p>Thank you for your interest in this resale property. Your KYC & Booking Form is ready.</p>'
            + '<p>Please complete the form using the secure link below. The link is valid for '
            + ResaleKycService.LINK_VALIDITY_DAYS + ' days.</p>'
            + '<p><a href="' + url + '" style="background:#0070d2;color:#fff;padding:10px 20px;border-radius:4px;text-decoration:none;font-weight:bold;">Complete KYC & Booking Form</a></p>'
            + '<p>If the button above does not work, copy and paste this URL into your browser:<br/>'
            + '<a href="' + url + '">' + url + '</a></p>'
            + '<p>For any queries, please contact your Relationship Manager: <strong>' + (rmName != null ? rmName : 'your RM') + '</strong>.</p>'
            + '<p>This is an automated email. Please do not reply.</p>'
        );
        mail.setSaveAsActivity(true);
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            // Log but do not fail the link generation if email fails
            System.debug(LoggingLevel.WARN, 'KYC link email not sent: ' + e.getMessage());
        }
    }
}