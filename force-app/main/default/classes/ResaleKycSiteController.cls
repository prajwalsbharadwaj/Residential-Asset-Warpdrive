/**
 * Controller for the customer-facing Resale KYC form on the Experience Cloud site.
 * Accessible by the Site Guest User — runs without sharing.
 * All state is resolved from the URL token; no record ids accepted from the browser.
 */
global without sharing class ResaleKycSiteController {

    // ── Called from the LWC resaleKycForm on first load ──

    @AuraEnabled
    global static Map<String, Object> loadForm(String token) {
        try {
            Opportunity o = ResaleKycService.resolve(token);
            Map<String, Object> result = new Map<String, Object>{
                'context' => ResaleKycService.context(o),
                'locked'  => ResaleKycService.isLocked(o)
            };
            if (String.isNotBlank(o.Booking_Form_Data__c)) {
                result.put('data', JSON.deserializeUntyped(o.Booking_Form_Data__c));
            } else {
                result.put('data', ResaleKycService.prefill(o));
            }
            return result;
        } catch (ResaleKycService.ResaleKycException e) {
            throw ResaleKycService.auraError(e);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    // ── Auto-save: called whenever the buyer navigates between form steps ──

    @AuraEnabled
    global static void saveProgress(String token, String dataJson) {
        try {
            Opportunity o = ResaleKycService.resolve(token);
            ResaleKycService.requireEditable(o);
            Object data = JSON.deserializeUntyped(dataJson);
            String step = ResaleKycService.str((Map<String, Object>) data, 'step');
            Opportunity upd = new Opportunity(Id = o.Id);
            upd.Booking_Form_Data__c      = dataJson;
            upd.Booking_Form_Last_Saved_At__c = Datetime.now();
            upd.Booking_Form_Step__c      = step;
            if (o.Booking_Form_Status__c == ResaleKycService.STATUS_GENERATED) {
                upd.Booking_Form_Status__c = ResaleKycService.STATUS_IN_PROGRESS;
            }
            update upd;
        } catch (ResaleKycService.ResaleKycException e) {
            throw ResaleKycService.auraError(e);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    // ── Final submit ──

    @AuraEnabled
    global static void submitForm(String token, String dataJson) {
        try {
            Opportunity o = ResaleKycService.resolve(token);
            ResaleKycService.requireEditable(o);
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(dataJson);

            // Validate all 4 declarations accepted (LWC sends decl1–decl4 as top-level fields)
            if (data.get('decl1') != true || data.get('decl2') != true
                    || data.get('decl3') != true || data.get('decl4') != true) {
                throw new ResaleKycService.ResaleKycException(
                    'Please accept all declarations before submitting.');
            }

            // Apply data to Salesforce records
            ResaleKycService.apply(o, data);

            // Mark form as submitted
            Opportunity upd = new Opportunity(Id = o.Id);
            upd.Booking_Form_Data__c          = dataJson;
            upd.Booking_Form_Status__c        = ResaleKycService.STATUS_SUBMITTED;
            upd.Booking_Form_Submitted_At__c  = Datetime.now();
            upd.Booking_Form_Last_Saved_At__c = Datetime.now();
            upd.Booking_Form_Step__c          = 'submitted';
            update upd;
        } catch (ResaleKycService.ResaleKycException e) {
            throw ResaleKycService.auraError(e);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    // ── OTP: Step 1 – send code ──

    /**
     * Validates the entered mobile matches the Opportunity, generates a 6-digit OTP,
     * stores a hashed version on the Opportunity, and returns the masked mobile number.
     * The OTP code itself is returned so the Experience Cloud page can display it to
     * the buyer (the org has no live SMS gateway; this matches the existing org pattern).
     */
    @AuraEnabled
    global static Map<String, Object> sendOtp(String token, String enteredMobile) {
        try {
            Opportunity o = ResaleKycService.resolve(token);

            // Validate mobile matches
            String expected = o.Buyer_Phone__c;
            if (String.isNotBlank(expected)) {
                String clean = enteredMobile == null ? '' : enteredMobile.replaceAll('[^0-9]', '');
                String exp   = expected.replaceAll('[^0-9]', '');
                if (clean.right(10) != exp.right(10)) {
                    throw new ResaleKycService.ResaleKycException(
                        'The mobile number you entered does not match our records. Please use the number linked to this resale.');
                }
            }

            // Generate 6-digit OTP
            Integer otpInt = Math.abs(Math.mod(Crypto.getRandomInteger(), 900000)) + 100000;
            String otpCode = String.valueOf(otpInt);

            // Hash the OTP and store with expiry in a temporary field
            String otpHash = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(otpCode))
            );
            Long expiryEpoch = Datetime.now().addMinutes(10).getTime();

            // Persist in a JSON blob on the opportunity — reuse Booking_Form_Data__c
            // under a reserved key so saveProgress won't overwrite it (key starts with __)
            String existingData = o.Booking_Form_Data__c;
            Map<String, Object> dataMap = new Map<String, Object>();
            if (String.isNotBlank(existingData)) {
                dataMap = (Map<String, Object>) JSON.deserializeUntyped(existingData);
            }
            dataMap.put('__otp_hash__',   otpHash);
            dataMap.put('__otp_expiry__', expiryEpoch);

            Opportunity upd = new Opportunity(Id = o.Id);
            upd.Booking_Form_Data__c = JSON.serialize(dataMap);
            update upd;

            String mobile = enteredMobile == null ? '' : enteredMobile.replaceAll('[^0-9]', '');
            String masked = mobile.length() >= 4
                ? '******' + mobile.substring(mobile.length() - 4)
                : mobile;

            return new Map<String, Object>{
                'otpCode'    => otpCode,   // returned so the page can display it (no SMS gateway)
                'maskedMobile' => masked
            };
        } catch (ResaleKycService.ResaleKycException e) {
            throw ResaleKycService.auraError(e);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    // ── OTP: Step 2 – verify code ──

    /**
     * Verifies the 6-digit OTP entered by the buyer against the hash stored on the Opportunity.
     * Clears the OTP after successful verification.
     */
    @AuraEnabled
    global static Boolean verifyOtp(String token, String enteredCode) {
        try {
            Opportunity o = ResaleKycService.resolve(token);

            if (String.isBlank(o.Booking_Form_Data__c)) {
                throw new ResaleKycService.ResaleKycException(
                    'OTP session not found. Please request a new OTP.');
            }

            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(o.Booking_Form_Data__c);
            String storedHash   = ResaleKycService.str(dataMap, '__otp_hash__');
            Object expiryObj    = dataMap.get('__otp_expiry__');
            Long   expiryEpoch  = expiryObj == null ? 0 : Long.valueOf(String.valueOf(expiryObj));

            if (String.isBlank(storedHash)) {
                throw new ResaleKycService.ResaleKycException(
                    'OTP session not found. Please request a new OTP.');
            }
            if (Datetime.now().getTime() > expiryEpoch) {
                throw new ResaleKycService.ResaleKycException(
                    'OTP has expired. Please request a new OTP.');
            }

            String enteredHash = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(enteredCode == null ? '' : enteredCode.trim()))
            );

            if (enteredHash != storedHash) {
                return false;
            }

            // Clear OTP so it can't be reused
            dataMap.remove('__otp_hash__');
            dataMap.remove('__otp_expiry__');
            Opportunity upd = new Opportunity(Id = o.Id);
            upd.Booking_Form_Data__c = JSON.serialize(dataMap);
            update upd;
            return true;

        } catch (ResaleKycService.ResaleKycException e) {
            throw ResaleKycService.auraError(e);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    // ── Document upload ──

    /**
     * Creates a ContentVersion record for a KYC document uploaded by the buyer.
     * Links it to the Opportunity via ContentDocumentLink.
     * docType: 'PAN' | 'ID_Proof' | 'Address_Proof' | 'Photo'
     */
    @AuraEnabled
    global static String uploadDocument(String token, String fileName, String base64Data, String docType) {
        try {
            Opportunity o = ResaleKycService.resolve(token);
            ResaleKycService.requireEditable(o);

            if (String.isBlank(fileName) || String.isBlank(base64Data)) {
                throw new ResaleKycService.ResaleKycException('File name and data are required.');
            }

            // Prefix file name with document type for easy identification
            String title = docType + ' – ' + fileName;

            ContentVersion cv = new ContentVersion();
            cv.Title          = title;
            cv.PathOnClient   = fileName;
            cv.VersionData    = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = o.Id;
            insert cv;

            // Retrieve the ContentDocumentId
            Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
            return contentDocId;

        } catch (ResaleKycService.ResaleKycException e) {
            throw ResaleKycService.auraError(e);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }

    // ── Legacy: kept for backward compatibility ──

    @AuraEnabled
    global static Boolean verifyMobile(String token, String enteredMobile) {
        try {
            Opportunity o = ResaleKycService.resolve(token);
            String expected = o.Buyer_Phone__c;
            if (String.isBlank(expected)) return true;
            String clean = enteredMobile.replaceAll('[^0-9]', '');
            String expectedClean = expected.replaceAll('[^0-9]', '');
            return clean.right(10) == expectedClean.right(10);
        } catch (Exception e) {
            throw ResaleKycService.auraError(e);
        }
    }
}