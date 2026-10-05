// Seed and link Demo Ledger data
List<Booking__c> bkgs = [SELECT Id, Name FROM Booking__c WHERE Name IN ('BKG-0007', 'BKG-0009')];
Map<String, Booking__c> bkgMap = new Map<String, Booking__c>();
for (Booking__c b : bkgs) {
    bkgMap.put(b.Name, b);
}

if (bkgMap.containsKey('BKG-0007')) {
    Booking__c b7 = bkgMap.get('BKG-0007');
    b7.Token_Amount__c = 950000;
    update b7;
}

if (bkgMap.containsKey('BKG-0009')) {
    Booking__c b9 = bkgMap.get('BKG-0009');
    b9.Token_Amount__c = 965000;
    update b9;
}

List<Installment__c> insts = [SELECT Id, Name, Booking__r.Name FROM Installment__c WHERE Name IN ('INST-0000', 'INST-0003', 'INST-0004')];
Map<String, Installment__c> instMap = new Map<String, Installment__c>();
for (Installment__c i : insts) {
    instMap.put(i.Name, i);
}

List<Receipt__c> rcpts = [SELECT Id, Name, Booking__c, Installment__c FROM Receipt__c WHERE Name IN ('RCPT-0000', 'RCPT-0001')];
for (Receipt__c r : rcpts) {
    if (r.Name == 'RCPT-0000' && bkgMap.containsKey('BKG-0007') && instMap.containsKey('INST-0000')) {
        r.Booking__c = bkgMap.get('BKG-0007').Id;
        r.Installment__c = instMap.get('INST-0000').Id;
    } else if (r.Name == 'RCPT-0001' && bkgMap.containsKey('BKG-0009') && instMap.containsKey('INST-0003')) {
        r.Booking__c = bkgMap.get('BKG-0009').Id;
        r.Installment__c = instMap.get('INST-0003').Id;
    }
}
update rcpts;

System.debug('=== Seeded Demo Ledger Data Successfully ===');
if (bkgMap.containsKey('BKG-0009')) {
    CustomerLedgerController.LedgerSummaryWrapper summary = CustomerLedgerController.getLedgerSummary(bkgMap.get('BKG-0009').Id);
    System.debug('BKG-0009 Summary: ' + JSON.serializePretty(summary));
}
