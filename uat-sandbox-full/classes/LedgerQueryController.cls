public with sharing class LedgerQueryController {
    @AuraEnabled(cacheable=true)
    public static LedgerEntryService.Balances getBookingBalances(Id bookingId) {
        return LedgerEntryService.getBalances(bookingId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Ledger_Entry__c> listLedger(Id bookingId) {
        if (bookingId == null) {
            return new List<Ledger_Entry__c>();
        }
        return [
            SELECT Id, Name, Entry_Date__c, Period_Start__c, Period_End__c,
                   Type__c, Bucket__c, Source__c, Status__c,
                   Principal_Amount__c, Interest_Amount__c, Tax_Amount__c, Total_Amount__c,
                   Running_Principal_Outstanding__c, Running_Interest_Outstanding__c, Running_Tax_Outstanding__c,
                   Payment_Receipt__c, Schedule__c, Reverses_Ledger__c, Description__c
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
            ORDER BY Entry_Date__c DESC, CreatedDate DESC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getBucketBalances(Id bookingId) {
        Map<String, Decimal> result = new Map<String, Decimal>();
        if (bookingId == null) {
            result.put(LedgerConst.BUCKET_BASIC, 0);
            result.put(LedgerConst.BUCKET_OTHER, 0);
            return result;
        }
        for (AggregateResult ar : [
            SELECT Bucket__c bucket,
                   SUM(Principal_Amount__c) prin,
                   SUM(Interest_Amount__c) intr,
                   SUM(Tax_Amount__c) tax
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
              AND Status__c = :LedgerConst.STATUS_POSTED
            GROUP BY Bucket__c
        ]) {
            String bucket = (String)ar.get('bucket');
            Decimal total = nz((Decimal)ar.get('prin')) + nz((Decimal)ar.get('intr')) + nz((Decimal)ar.get('tax'));
            result.put(bucket == null ? LedgerConst.BUCKET_BASIC : bucket, total.setScale(2, RoundingMode.HALF_UP));
        }
        if (!result.containsKey(LedgerConst.BUCKET_BASIC)) {
            result.put(LedgerConst.BUCKET_BASIC, 0);
        }
        if (!result.containsKey(LedgerConst.BUCKET_OTHER)) {
            result.put(LedgerConst.BUCKET_OTHER, 0);
        }
        return result;
    }

    private static Decimal nz(Decimal value) {
        return value == null ? 0 : value;
    }
}