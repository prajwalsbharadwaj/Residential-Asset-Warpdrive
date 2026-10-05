public class StatementEntry {
    public String milestone { get; set; }
    public Date dueDate { get; set; }
    public Decimal demandAmount { get; set; }
    public Decimal amountPaid { get; set; }
    public Decimal amountOutstanding { get; set; }
    public Decimal interestOutstanding { get; set; }

    public StatementEntry(String milestone, Date dueDate, Decimal demandAmount, Decimal amountPaid, Decimal amountOutstanding, Decimal interestOutstanding) {
        this.milestone = milestone;
        this.dueDate = dueDate;
        this.demandAmount = demandAmount;
        this.amountPaid = amountPaid;
        this.amountOutstanding = amountOutstanding;
        this.interestOutstanding = interestOutstanding;
    }
}