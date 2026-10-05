public with sharing class ResaleSalesOfferController {

    // ── Quote-level action (existing, kept for backward compat) ──────────────

    @AuraEnabled
    public static void saveSalesOffer(Id quoteId, String paymentTermsJson) {
        try {
            Quote q = [
                SELECT Id, Name, OpportunityId,
                    Proposed_Resale_Value__c, Resale_Charges__c,
                    Resale_Brokerage_Fee__c, Resale_Discount__c,
                    Final_Resale_Value__c, GrandTotal,
                    Opportunity.Name, Opportunity.Buyer_Name__c,
                    Opportunity.Interested_Unit__r.Name,
                    Opportunity.Interested_Unit__r.Property__r.Name
                FROM Quote WHERE Id = :quoteId LIMIT 1
            ];
            Map<String, Object> terms = (Map<String, Object>) JSON.deserializeUntyped(paymentTermsJson);
            String content = buildOfferSummary(q, terms);

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Sales Offer – ' + q.Name + ' – ' + Datetime.now().format('dd MMM yyyy');
            cv.PathOnClient = 'SalesOffer_' + q.Name + '.txt';
            cv.VersionData = Blob.valueOf(content);
            cv.FirstPublishLocationId = quoteId;
            insert cv;

            if (q.OpportunityId != null) {
                Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
                insert new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId = q.OpportunityId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
            }
        } catch (Exception e) {
            throw new AuraHandledException('Could not save Sales Offer: ' + e.getMessage());
        }
    }

    // ── Quote-level action: generates actual PDF from VF page ────────────────

    @AuraEnabled
    public static Id saveSalesOfferPDF(Id quoteId, String paymentTermsJson) {
        try {
            Quote q = [SELECT Id, Name, OpportunityId FROM Quote WHERE Id = :quoteId LIMIT 1];
            Map<String, Object> terms = (Map<String, Object>) JSON.deserializeUntyped(paymentTermsJson);

            PageReference pdfPage = Page.ResaleSalesOrderPDF;
            pdfPage.getParameters().put('quoteId', quoteId);
            pdfPage.getParameters().put('paymentType', strVal(terms, 'paymentType'));
            pdfPage.getParameters().put('dueDate', strVal(terms, 'dueDate'));
            pdfPage.getParameters().put('remarks', strVal(terms, 'remarks'));

            Blob pdfContent = Test.isRunningTest() ? Blob.valueOf('PDF_PLACEHOLDER') : pdfPage.getContent();

            String title = 'Sales Offer – ' + q.Name + ' – ' + Datetime.now().format('dd MMM yyyy');
            ContentVersion cv = new ContentVersion();
            cv.Title                  = title;
            cv.PathOnClient           = 'SalesOffer_' + q.Name + '.pdf';
            cv.VersionData            = pdfContent;
            cv.FirstPublishLocationId = quoteId;
            cv.ContentLocation        = 'S';
            insert cv;

            Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
            if (q.OpportunityId != null) {
                insert new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId    = q.OpportunityId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                );
            }
            return docId;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Could not generate Sales Offer PDF: ' + e.getMessage());
        }
    }

    // ── Opportunity-level action: finds approved Final Quote, generates PDF ──

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getApprovedQuoteData(Id opportunityId) {
        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber,
                Proposed_Resale_Value__c, Resale_Charges__c,
                Resale_Brokerage_Fee__c, Resale_Discount__c,
                Final_Resale_Value__c, Original_Booking_Value__c,
                Chargeable_Area__c
            FROM Quote
            WHERE OpportunityId = :opportunityId
            AND Final_Quote__c = true
            AND Simulation_Status__c = 'Approved'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (quotes.isEmpty()) return null;
        Quote q = quotes[0];
        return new Map<String, Object>{
            'quoteId'             => q.Id,
            'quoteNumber'         => q.Name,
            'proposedResaleValue' => q.Proposed_Resale_Value__c,
            'resaleCharges'       => q.Resale_Charges__c,
            'brokerageFee'        => q.Resale_Brokerage_Fee__c,
            'discount'            => q.Resale_Discount__c,
            'finalResaleValue'    => q.Final_Resale_Value__c,
            'originalBookingValue'=> q.Original_Booking_Value__c,
            'chargeableArea'      => q.Chargeable_Area__c
        };
    }

    @AuraEnabled
    public static Id saveSalesOrderFromOpportunity(Id opportunityId, String paymentTermsJson) {
        try {
            // Query before any DML so PageReference.getContent() can be called
            List<Quote> quotes = [
                SELECT Id, Name
                FROM Quote
                WHERE OpportunityId = :opportunityId
                AND Final_Quote__c = true
                AND Simulation_Status__c = 'Approved'
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (quotes.isEmpty()) {
                throw new AuraHandledException('No approved Final Quote found for this Opportunity.');
            }
            Quote q = quotes[0];
            Map<String, Object> terms = (Map<String, Object>) JSON.deserializeUntyped(paymentTermsJson);

            // Render PDF via VF page before DML
            PageReference pdfPage = Page.ResaleSalesOrderPDF;
            pdfPage.getParameters().put('quoteId', q.Id);
            pdfPage.getParameters().put('paymentType', strVal(terms, 'paymentType'));
            pdfPage.getParameters().put('dueDate', strVal(terms, 'dueDate'));
            pdfPage.getParameters().put('remarks', strVal(terms, 'remarks'));

            Blob pdfContent;
            if (Test.isRunningTest()) {
                pdfContent = Blob.valueOf('PDF_PLACEHOLDER');
            } else {
                pdfContent = pdfPage.getContent();
            }

            String title = 'Sales Order – ' + q.Name + ' – ' + Datetime.now().format('dd MMM yyyy');

            // Store as ContentVersion linked to Opportunity
            ContentVersion cv = new ContentVersion();
            cv.Title             = title;
            cv.PathOnClient      = 'SalesOrder_' + q.Name + '.pdf';
            cv.VersionData       = pdfContent;
            cv.FirstPublishLocationId = opportunityId;
            cv.ContentLocation   = 'S';
            insert cv;

            // Return the ContentDocumentId so LWC can offer navigation
            return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Could not generate Sales Order: ' + e.getMessage());
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private static String buildOfferSummary(Quote q, Map<String, Object> terms) {
        String nl = '\n';
        Decimal proposed  = q.Proposed_Resale_Value__c != null ? q.Proposed_Resale_Value__c : 0;
        Decimal charges   = q.Resale_Charges__c        != null ? q.Resale_Charges__c : 0;
        Decimal brokerage = q.Resale_Brokerage_Fee__c  != null ? q.Resale_Brokerage_Fee__c : 0;
        Decimal discount  = q.Resale_Discount__c       != null ? q.Resale_Discount__c : 0;
        Decimal total     = proposed + charges + brokerage - discount;

        return 'NIKOO HOMES – RESALE SALES OFFER' + nl
            + '====================================' + nl
            + 'Date: ' + Datetime.now().format('dd MMM yyyy') + nl + nl
            + 'PROPERTY DETAILS' + nl + '----------------' + nl
            + 'Quote No.  : ' + q.Name + nl
            + 'Opportunity: ' + (q.Opportunity?.Name != null ? q.Opportunity.Name : '') + nl
            + 'Buyer      : ' + (q.Opportunity?.Buyer_Name__c != null ? q.Opportunity.Buyer_Name__c : '') + nl
            + 'Unit       : ' + (q.Opportunity?.Interested_Unit__r?.Name != null ? q.Opportunity.Interested_Unit__r.Name : '') + nl
            + 'Project    : ' + (q.Opportunity?.Interested_Unit__r?.Property__r?.Name != null ? q.Opportunity.Interested_Unit__r.Property__r.Name : '') + nl + nl
            + 'COMMERCIAL SUMMARY' + nl + '------------------' + nl
            + 'Proposed Resale Value  : INR ' + proposed.setScale(2) + nl
            + 'Applicable Charges     : INR ' + charges.setScale(2) + nl
            + 'Brokerage / Service Fee: INR ' + brokerage.setScale(2) + nl
            + 'Discount / Adjustment  : INR ' + discount.setScale(2) + nl
            + '-----------------------------' + nl
            + 'GRAND TOTAL            : INR ' + total.setScale(2) + nl + nl
            + 'PAYMENT TERMS' + nl + '-------------' + nl
            + 'Payment Type  : ' + strVal(terms, 'paymentType') + nl
            + 'Due Date      : ' + strVal(terms, 'dueDate') + nl
            + 'Remarks       : ' + strVal(terms, 'remarks') + nl;
    }

    private static String strVal(Map<String, Object> m, String key) {
        Object v = m == null ? null : m.get(key);
        return v == null ? '' : String.valueOf(v);
    }
}