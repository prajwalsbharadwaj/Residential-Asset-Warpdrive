/**
 * Shared logic for the Resale Buyer KYC & Booking Form.
 *
 * Mirrors the BookingFormService pattern. The form is keyed by Opportunity.Booking_Form_Token__c
 * (reusing existing fields) when the Opportunity is a Resale Assistance record.
 * KYC data is kept as JSON in Booking_Form_Data__c while the buyer fills it;
 * on submit the data is mapped onto the Buyer_Contact__c Account and Opportunity fields.
 *
 * Runs without sharing so the Experience Cloud guest user can call it.
 * All entry points resolve the Opportunity from the token — never from a record id in the URL.
 */
public without sharing class ResaleKycService {

    public static final Integer LINK_VALIDITY_DAYS = 30;
    public static final String SITE_NAME = 'Nikoo Homes Booking';
    public static final String FORM_PATH = '/resale-kyc';

    public static final String STATUS_GENERATED   = 'Link Generated';
    public static final String STATUS_IN_PROGRESS = 'In Progress';
    public static final String STATUS_SUBMITTED    = 'Submitted';

    public class ResaleKycException extends Exception {}

    // ──────────────────────── Token ────────────────────────

    public static String newToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }

    /** Resolves an Opportunity from its Resale KYC token. Throws on invalid / expired. */
    public static Opportunity resolve(String token) {
        if (String.isBlank(token) || token.length() != 64) {
            throw new ResaleKycException('This link is not valid. Please use the link shared by your relationship manager.');
        }
        List<Opportunity> opps = [
            SELECT Id, Name, OwnerId, Owner.Name, Owner.Email, Owner.MobilePhone,
                AccountId, Account.Name, Account.PersonEmail, Account.PersonMobilePhone,
                Buyer_Name__c, Buyer_Phone__c, Buyer_Email__c,
                Buyer_Contact__c, Buyer_Contact__r.Name,
                Expected_Resale_Price__c, Final_Resale_Value__c,
                Interested_Unit__c, Interested_Unit__r.Name,
                Interested_Unit__r.Property__r.Name, Interested_Unit__r.Tower__r.Name,
                Booking_Form_Token__c, Booking_Form_Status__c, Booking_Form_Step__c,
                Booking_Form_Data__c, Booking_Form_Expires_On__c,
                Booking_Form_Submitted_At__c, Booking_Form_Generated_At__c,
                Booking_Form_Last_Saved_At__c, RecordType.DeveloperName
            FROM Opportunity
            WHERE Booking_Form_Token__c = :token
              AND RecordType.DeveloperName = 'Resale_Assistance'
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw new ResaleKycException('This link is no longer valid. Please ask your relationship manager for a new link.');
        }
        Opportunity o = opps[0];
        if (o.Booking_Form_Expires_On__c != null
                && o.Booking_Form_Expires_On__c < Date.today()
                && o.Booking_Form_Status__c != STATUS_SUBMITTED) {
            throw new ResaleKycException('This link has expired. Please ask your relationship manager for a new link.');
        }
        return o;
    }

    public static Boolean isLocked(Opportunity o) {
        return o.Booking_Form_Status__c == STATUS_SUBMITTED;
    }

    public static void requireEditable(Opportunity o) {
        if (isLocked(o)) {
            throw new ResaleKycException('This form has already been submitted. Contact your relationship manager to make changes.');
        }
    }

    // ──────────────────────── Prefill ────────────────────────

    /** Returns the initial JSON state for the form, pre-filled with known buyer data. */
    public static Map<String, Object> prefill(Opportunity o) {
        Map<String, Object> buyer = new Map<String, Object>{
            'fullLegalName' => o.Buyer_Name__c,
            'mobile'        => o.Buyer_Phone__c,
            'email'         => o.Buyer_Email__c,
            'pan'           => '',
            'aadhaar'       => '',
            'dob'           => '',
            'address'       => new Map<String, Object>{ 'country' => 'India' },
            'idProofType'   => 'Aadhaar',
            'documents'     => new Map<String, Object>(),
            'signature'     => null
        };

        // If buyer account already exists, prefill richer data from it
        if (o.Buyer_Contact__c != null) {
            List<Account> accts = [
                SELECT Id, Name, PAN_Number__c, Aadhar_Number__c, PersonBirthdate,
                    PersonEmail, PersonMobilePhone, PersonMailingStreet, PersonMailingCity,
                    PersonMailingState, PersonMailingPostalCode
                FROM Account WHERE PersonContactId = :o.Buyer_Contact__c LIMIT 1
            ];
            if (!accts.isEmpty()) {
                Account a = accts[0];
                if (String.isNotBlank(a.PAN_Number__c))   buyer.put('pan', a.PAN_Number__c);
                if (String.isNotBlank(a.Aadhar_Number__c)) buyer.put('aadhaar', a.Aadhar_Number__c);
                if (a.PersonBirthdate != null) buyer.put('dob', String.valueOf(a.PersonBirthdate));
                Map<String, Object> addr = new Map<String, Object>{
                    'line1'   => a.PersonMailingStreet,
                    'city'    => a.PersonMailingCity,
                    'state'   => a.PersonMailingState,
                    'pincode' => a.PersonMailingPostalCode,
                    'country' => 'India'
                };
                buyer.put('address', addr);
            }
        }

        return new Map<String, Object>{
            'step'         => 'kyc',
            'buyer'        => buyer,
            'declarations' => new Map<String, Object>{
                'termsAccepted'   => false,
                'kycVerified'     => false,
                'infoCorrect'     => false
            }
        };
    }

    // ──────────────────────── Context ────────────────────────

    /** Returns display context (project, unit, RM info) for the form header. */
    public static Map<String, Object> context(Opportunity o) {
        return new Map<String, Object>{
            'opportunityName'   => o.Name,
            'buyerName'         => o.Buyer_Name__c,
            'project'           => o.Interested_Unit__r?.Property__r?.Name,
            'tower'             => o.Interested_Unit__r?.Tower__r?.Name,
            'unit'              => o.Interested_Unit__r?.Name,
            'agreedValue'       => o.Final_Resale_Value__c != null ? o.Final_Resale_Value__c : o.Expected_Resale_Price__c,
            'relationshipManager' => o.Owner?.Name
        };
    }

    // ──────────────────────── Submit ────────────────────────

    /**
     * Maps submitted KYC data back onto Salesforce records.
     * Updates the buyer Account with PAN, Aadhaar, address.
     * Marks KYC-related fields on the Opportunity.
     */
    public static void apply(Opportunity o, Map<String, Object> data) {
        Map<String, Object> buyer = (Map<String, Object>) data.get('buyer');
        Map<String, Object> declarations = (Map<String, Object>) data.get('declarations');

        // Update buyer Account if we know who it is
        Id buyerAccountId = getBuyerAccountId(o);
        if (buyerAccountId != null && buyer != null) {
            Account a = new Account(Id = buyerAccountId);
            String pan = str(buyer, 'pan');
            String aadhaar = str(buyer, 'aadhaar');
            if (String.isNotBlank(pan))    a.PAN_Number__c = pan.toUpperCase();
            if (String.isNotBlank(aadhaar)) a.Aadhar_Number__c = aadhaar;
            String dob = str(buyer, 'dob');
            if (String.isNotBlank(dob)) {
                try { a.put('PersonBirthdate', Date.valueOf(dob.left(10))); } catch (Exception e) {}
            }
            Map<String, Object> addr = (Map<String, Object>) buyer.get('address');
            if (addr != null && String.isNotBlank(str(addr, 'line1'))) {
                a.put('PersonMailingStreet', str(addr, 'line1'));
                a.put('PersonMailingCity', str(addr, 'city'));
                a.put('PersonMailingState', str(addr, 'state'));
                a.put('PersonMailingPostalCode', str(addr, 'pincode'));
                a.put('PersonMailingCountry', String.isNotBlank(str(addr, 'country')) ? str(addr, 'country') : 'India');
            }
            try { update a; } catch (Exception e) {
                // Address state/country picklist mismatch — clear and retry
                for (String f : new List<String>{ 'PersonMailingStreet','PersonMailingCity','PersonMailingState','PersonMailingPostalCode','PersonMailingCountry' }) {
                    a.put(f, null);
                }
                update a;
            }
        }

        // Mark Opportunity KYC fields
        Boolean allDecls = (data.get('decl1') == true && data.get('decl2') == true
                         && data.get('decl3') == true && data.get('decl4') == true);
        Opportunity upd = new Opportunity(Id = o.Id);
        upd.Buyer_KYC_Status__c = 'Completed';
        upd.KYC_Declaration_Verified__c = allDecls;
        upd.Booking_Declaration_Accepted__c = allDecls;
        upd.PAN_Verified__c = (buyer != null && String.isNotBlank(str(buyer, 'pan')));
        Boolean hasDocs = (buyer != null && buyer.get('documents') instanceof Map<String, Object>
                          && !((Map<String, Object>) buyer.get('documents')).isEmpty());
        upd.Address_Proof_Verified__c = hasDocs;
        update upd;
    }

    private static Id getBuyerAccountId(Opportunity o) {
        if (o.AccountId != null) return o.AccountId;
        if (o.Buyer_Contact__c != null) {
            List<Account> a = [SELECT Id FROM Account WHERE PersonContactId = :o.Buyer_Contact__c LIMIT 1];
            if (!a.isEmpty()) return a[0].Id;
        }
        return null;
    }

    // ──────────────────────── Helpers ────────────────────────

    public static String str(Map<String, Object> m, String key) {
        Object v = m == null ? null : m.get(key);
        return v == null ? null : String.valueOf(v);
    }

    public static AuraHandledException auraError(Exception e) {
        AuraHandledException ex = new AuraHandledException(e.getMessage());
        ex.setMessage(e.getMessage());
        return ex;
    }

    /** Builds the site base URL for the Nikoo Homes Booking Experience Cloud site. */
    public static String siteBaseUrl() {
        for (Site s : [SELECT Id, Name, GuestUserId, UrlPathPrefix FROM Site WHERE Name = :SITE_NAME AND Status = 'Active' LIMIT 1]) {
            String base = Site.getBaseUrl();
            if (base != null) {
                return base;
            }
        }
        try {
            String base = System.Site.getBaseUrl();
            return base;
        } catch (Exception e) {}
        return null;
    }
}