// ----------------------
// Ledger Wrapper
// ----------------------
public class LedgerStatement {
    public Map<String, String> content { get; set; }
    public List<Entry> entry { get; set; }

    // New fields for totals and balance
    public Decimal totalInterest { get; set; }
    public Decimal totalDebits { get; set; }
    public Decimal totalCredits { get; set; }
    public Decimal totalBalance { get; set; }
    public Date closingDate { get; set; }

    public LedgerStatement() {
        content = new Map<String, String>();
        entry = new List<Entry>();
        totalInterest = 0;
        totalDebits = 0;
        totalCredits = 0;
        totalBalance = 0;
        closingDate = closingDate;
    }

    public class Entry {
        public Integer sortOrder { get; set; }       // SL No.
        public Date entryDate { get; set; }          // Created Date (either demand or payment)
        public Date demandDate { get; set; }         // Payment Due Date for Demands
        public String particulars { get; set; }      // Description like 'Demand: X' or 'Payment: Y'
        public Decimal debit { get; set; }           // Debit amount (positive for demand)
        public Decimal credit { get; set; }          // Credit amount (positive for receipt)
        public Decimal balance { get; set; }         // Running balance (positive)

        public Entry(Integer sortOrder, Date entryDate, Date demandDate, String particulars,
                     Decimal debit, Decimal credit, Decimal balance) {
            this.sortOrder = sortOrder;
            this.entryDate = entryDate;
            this.demandDate = demandDate;
            this.particulars = particulars;
            this.debit = debit;
            this.credit = credit;
            this.balance = balance;
        }
    }
}