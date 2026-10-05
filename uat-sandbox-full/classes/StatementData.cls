public class StatementData {
    public Map<String, String> content { get; set; }
    public List<PaymentScheduleEntry> schedules { get; set; }
    public List<ReceiptEntry> receipts { get; set; }
    public SummaryInfo summary { get; set; }

    public StatementData() {
        content = new Map<String, String>();
        schedules = new List<PaymentScheduleEntry>();
        receipts = new List<ReceiptEntry>();
        summary = new SummaryInfo();
    }

    public class PaymentScheduleEntry {
        public String milestone { get; set; }
        public String dueDate { get; set; }
        public Decimal amount { get; set; }
        public Decimal outstanding { get; set; }
        public Decimal interest { get; set; }

        public PaymentScheduleEntry(String milestone, String dueDate, Decimal amount, Decimal outstanding) {
            this.milestone = milestone;
            this.dueDate = dueDate;
            this.amount = amount;
            this.outstanding = outstanding;
            this.interest = 0;
        }
    }

    public class ReceiptEntry {
        public String receiptNumber { get; set; }
        public String receiptDate { get; set; }
        public String paymentMode { get; set; }
        public String bankName { get; set; }
        public String instrumentDate { get; set; }
        public String instrumentNumber { get; set; }
        public Decimal amountReceived { get; set; }

        public ReceiptEntry(String receiptNumber, String receiptDate, String paymentMode, String bankName, String instrumentDate, String instrumentNumber, Decimal amountReceived) {
            this.receiptNumber = receiptNumber;
            this.receiptDate = receiptDate;
            this.paymentMode = paymentMode;
            this.bankName = bankName;
            this.instrumentDate = instrumentDate;
            this.instrumentNumber = instrumentNumber;
            this.amountReceived = amountReceived;
        }
    }

    public class SummaryInfo {
        public Decimal totalAmountReceived { get; set; }
        public Decimal totalAmountOutstanding { get; set; }
        public Decimal balancePayable { get; set; }
        public Decimal totalIncludingExcess { get; set; }
        public Decimal balanceIncludingInterest { get; set; }
        public Decimal totalApartmentCost { get; set; }
        public Decimal totalDemandAmount { get; set; }

        public SummaryInfo() {
            totalAmountOutstanding = 0;
            totalAmountReceived = 0;
            balancePayable = 0;
            totalIncludingExcess = 0;
            balanceIncludingInterest = 0;
            totalApartmentCost = 0;
            totalDemandAmount = 0;
        }
    }
}