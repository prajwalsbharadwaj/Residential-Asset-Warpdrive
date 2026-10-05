public class LedgerEntry {
    public Date entryDate { get; set; }
    public String particulars { get; set; }
    public Decimal debit { get; set; }
    public Decimal credit { get; set; }
    public Decimal balance { get; set; }

    public LedgerEntry(Date entryDate, String particulars, Decimal debit, Decimal credit, Decimal balance) {
        this.entryDate = entryDate;
        this.particulars = particulars;
        this.debit = debit;
        this.credit = credit;
        this.balance = balance;
    }
}