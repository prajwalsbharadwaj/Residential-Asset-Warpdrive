public class TransactionReportController {
    public Id bookingId { get; set; }
    public Booking__c booking { get; set; }
    public ReportWrapper wrapper { get; set; }

    public TransactionReportController() {
        bookingId = ApexPages.currentPage().getParameters().get('bookingId');

        if (bookingId != null) {
            booking = [
                SELECT Id, Name, Booking_Date__c, Remarks__c,
                       Project__r.Name,
                       Account_Id__r.Name,
                       Account_Id__r.Phone,
                       Account_Id__r.PAN_Number__c,
                       Account_Id__r.PersonBirthdate,
                       Account_Id__r.PersonMailingStreet,
                       Account_Id__r.PersonMailingCity,
                       Account_Id__r.PersonMailingState,
                       Account_Id__r.PersonMailingPostalCode,
                       Account_Id__r.PersonMailingCountry,
                       Account_Id__r.PersonEmail,
                       Co_Applicant_1__r.Name,
                       Co_Applicant_1__r.PersonEmail,
                       Co_Applicant_2__r.Name,
                       Co_Applicant_2__r.PersonEmail,
                       Co_Applicant_3__r.Name,
                       Co_Applicant_3__r.PersonEmail,
                       Co_Applicant_4__r.Name,
                       Co_Applicant_4__r.PersonEmail,
                       Co_Applicant_5__r.Name,
                       Co_Applicant_5__r.PersonEmail,
                       Unit_Id__r.Name,
                       Unit_Id__r.Terrace_Area__c,
                       Unit_Id__r.Carpet_Area__c,
                       Unit_Id__r.Tower__r.Name,
                       Unit_Id__r.Floor__r.Name,
                       Unit_Id__r.BHK_Configuration__c,
                       Unit_Id__r.Built_Up_Area_SBA__c,
                       Payment_Plan_Id__r.Name,
                       Opportunity_Id__c
                FROM Booking__c
                WHERE Id = :bookingId
                LIMIT 1
            ];
        }

        wrapper = new ReportWrapper();

        // --- Header ---
        wrapper.currentDate = Datetime.now().format('MMM dd, yyyy');

        // --- Customer Info ---
        wrapper.project = (booking != null && booking.Project__r != null) ? booking.Project__r.Name : null;
        wrapper.customerName = (booking != null && booking.Account_Id__r != null) ? booking.Account_Id__r.Name : null;

        // co applicant list builder
        List<CoApplicantWrapper> coApplicants = new List<CoApplicantWrapper>();
        Integer counter = 1;

        if (booking.Co_Applicant_1__r != null) {
            coApplicants.add(new CoApplicantWrapper(
                counter++,
                booking.Co_Applicant_1__r.Name +
                (String.isNotBlank(booking.Co_Applicant_1__r.PersonEmail) ? ' / ' + booking.Co_Applicant_1__r.PersonEmail : '')
            ));
        }
        if (booking.Co_Applicant_2__r != null) {
            coApplicants.add(new CoApplicantWrapper(
                counter++,
                booking.Co_Applicant_2__r.Name +
                (String.isNotBlank(booking.Co_Applicant_2__r.PersonEmail) ? ' / ' + booking.Co_Applicant_2__r.PersonEmail : '')
            ));
        }
        if (booking.Co_Applicant_3__r != null) {
            coApplicants.add(new CoApplicantWrapper(
                counter++,
                booking.Co_Applicant_3__r.Name +
                (String.isNotBlank(booking.Co_Applicant_3__r.PersonEmail) ? ' / ' + booking.Co_Applicant_3__r.PersonEmail : '')
            ));
        }
        if (booking.Co_Applicant_4__r != null) {
            coApplicants.add(new CoApplicantWrapper(
                counter++,
                booking.Co_Applicant_4__r.Name +
                (String.isNotBlank(booking.Co_Applicant_4__r.PersonEmail) ? ' / ' + booking.Co_Applicant_4__r.PersonEmail : '')
            ));
        }
        if (booking.Co_Applicant_5__r != null) {
            coApplicants.add(new CoApplicantWrapper(
                counter++,
                booking.Co_Applicant_5__r.Name +
                (String.isNotBlank(booking.Co_Applicant_5__r.PersonEmail) ? ' / ' + booking.Co_Applicant_5__r.PersonEmail : '')
            ));
        }

        // store in wrapper
        wrapper.coApplicants = coApplicants;

        wrapper.customerPan = (booking != null && booking.Account_Id__r != null) ? booking.Account_Id__r.PAN_Number__c : null;
        wrapper.dateOfBirth = (booking != null && booking.Account_Id__r != null && booking.Account_Id__r.PersonBirthdate != null)
                             ? Datetime.newInstance(booking.Account_Id__r.PersonBirthdate, Time.newInstance(0,0,0,0)).format('MMM dd, yyyy')
                             : '';
        wrapper.codeNo = '';

        // --- Address ---
        if (booking != null && booking.Account_Id__r != null) {
            wrapper.address =
                (booking.Account_Id__r.PersonMailingStreet != null ? booking.Account_Id__r.PersonMailingStreet + ', ' : '') +
                (booking.Account_Id__r.PersonMailingCity != null ? booking.Account_Id__r.PersonMailingCity + ', ' : '') +
                (booking.Account_Id__r.PersonMailingState != null ? booking.Account_Id__r.PersonMailingState + ', ' : '') +
                (booking.Account_Id__r.PersonMailingPostalCode != null ? 'PINCODE - ' + booking.Account_Id__r.PersonMailingPostalCode : '') +
                (booking.Account_Id__r.PersonMailingCountry != null ? ', ' + booking.Account_Id__r.PersonMailingCountry : '');
        }

        wrapper.contactNo = (booking != null && booking.Account_Id__r != null) ? formatPhone(booking.Account_Id__r.Phone) : null;
        wrapper.email = (booking != null && booking.Account_Id__r != null) ? booking.Account_Id__r.PersonEmail : null;
        wrapper.bookingDate = (booking != null && booking.Booking_Date__c != null)
                              ? Datetime.newInstance(booking.Booking_Date__c, Time.newInstance(0,0,0,0)).format('MMM dd, yyyy') : '';
        wrapper.bookingRemarks = (booking != null && booking.Remarks__c != null) ? booking.Remarks__c : 'No remarks';

        // --- Property Details ---
        wrapper.unitNo = (booking != null && booking.Unit_Id__r != null) ? booking.Unit_Id__r.Name : null;
        wrapper.tower = (booking != null && booking.Unit_Id__r != null && booking.Unit_Id__r.Tower__r != null) ? booking.Unit_Id__r.Tower__r.Name : null;
        wrapper.floor = (booking != null && booking.Unit_Id__r != null && booking.Unit_Id__r.Floor__r != null) ? booking.Unit_Id__r.Floor__r.Name : null;
        wrapper.type = (booking != null && booking.Unit_Id__r != null) ? booking.Unit_Id__r.BHK_Configuration__c : null;
        wrapper.superBuiltUpArea = (booking != null && booking.Unit_Id__r != null && booking.Unit_Id__r.Built_Up_Area_SBA__c != null)
                                   ? booking.Unit_Id__r.Built_Up_Area_SBA__c + ' SqFt' : '';
        wrapper.terraceArea = (booking != null && booking.Unit_Id__r != null && booking.Unit_Id__r.Terrace_Area__c != null)
                              ? booking.Unit_Id__r.Terrace_Area__c + ' SqFt' : '';
        wrapper.carpetArea = (booking != null && booking.Unit_Id__r != null && booking.Unit_Id__r.Carpet_Area__c != null)
                              ? booking.Unit_Id__r.Carpet_Area__c + ' SqFt' : '';

        // =========================================================
        // Financials (from ChargesCalculationHelper)
        // =========================================================
        ChargesCalculationHelper.FinancialsWrapper fin = null;
        
        if (booking != null && booking.Opportunity_Id__c != null) {
            try {
                fin = ChargesCalculationHelper.calculateCharges(booking.Opportunity_Id__c);
            } catch (Exception ex) {
                throw ex;
            }
        }
        
        Decimal landCost = 0, constructionCost = 0, taxOnLand = 0, taxOnConstruction = 0;
        Decimal totalSaleConsideration = 0, totalOtherCharges = 0, discountOnSale = 0, grandTotal = 0, cgstOnOtherCharges = 0, sgstOnOtherCharges = 0;
        
        if (fin != null) {
            landCost = (Decimal)fin.landCost.get('calculatedAmount');
            constructionCost = (Decimal)fin.constructionCost.get('calculatedAmount');
            taxOnLand = (Decimal)fin.Summary.get('taxOnLandCost');
            taxOnConstruction = (Decimal)fin.Summary.get('taxOnConstructionCost');
            totalSaleConsideration = (Decimal)fin.Summary.get('LandCost') + (Decimal)fin.Summary.get('ConstructionCost');
            discountOnSale = (Decimal)fin.discount.get('amount');
            totalOtherCharges = (Decimal)fin.otherChargesSummary.get('grandTotalOtherCharges');
            grandTotal = (Decimal)fin.Summary.get('grandTotal');
            cgstOnOtherCharges = (Decimal)fin.Summary.get('cgstOnOtherCharges');
            sgstOnOtherCharges = (Decimal)fin.Summary.get('sgstOnOtherCharges');
        }
        
        // --- Price & Discount ---  
        wrapper.grandTotal = grandTotal;
       // wrapper.totalLandConstPrice = totalSaleConsideration + taxOnLand + taxOnConstruction - discountOnSale;
       wrapper.totalLandConstPrice = totalSaleConsideration + taxOnLand + taxOnConstruction;
        wrapper.totalOtherCost = totalOtherCharges;
        
        wrapper.payPlanDiscount = 0.00;
        wrapper.counterDiscount = 0.00;
        wrapper.totalBrokerage = 0.00;
        
        // --- Sale Consideration ---
        wrapper.saleConsideration = new List<ChargeRow>{
            new ChargeRow('Land Cost', landCost + taxOnLand),
            new ChargeRow('Construction Cost', constructionCost + taxOnConstruction),
            // new ChargeRow('Tax on Land', taxOnLand),
            // new ChargeRow('Tax on Construction', taxOnConstruction),
            new ChargeRow('Total Sale Consideration', totalSaleConsideration + taxOnLand + taxOnConstruction, true)
        };
        
        // --- Other Charges (detailed) ---
        List<ChargeRow> otherChargeRows = new List<ChargeRow>();
        
        for (ChargesCalculationHelper.OtherChargeRow oc : fin.otherCharges) {
            String chargeName = oc.name;
            otherChargeRows.add(new ChargeRow(chargeName, oc.amountByType));
            
        }
        
        //tax rows for other charges
        otherChargeRows.add(new ChargeRow('CGST 9% Others', cgstOnOtherCharges));
        otherChargeRows.add(new ChargeRow('SGST 9% Others', sgstOnOtherCharges));
        
        // Add summary row
        Decimal grandOther = (fin.otherChargesSummary.containsKey('grandTotalOtherCharges'))
            ? (Decimal)fin.otherChargesSummary.get('grandTotalOtherCharges')
            : 0;
        
        otherChargeRows.add(new ChargeRow('Total Other Charges', grandOther, true));
        
        // assign to wrapper
        wrapper.otherCharges = otherChargeRows;

        // --- Payment Plan ---
        wrapper.paymentPlan = (booking != null && booking.Payment_Plan_Id__r != null) ? booking.Payment_Plan_Id__r.Name : null;

        // --- Brokerage ---
        List<Agent_Brokerage__c> brokerages = (booking != null) ? [
            SELECT Id, Name, Total_Bokerage__c, Account__r.Name, Bokerage_Amount__c,
                   Bokerage_Percentage__c, Bokerage_Type__c, Account__r.Phone, Account__r.Vendor_Name__c
            FROM Agent_Brokerage__c
            WHERE Booking__c = :booking.Id
        ] : new List<Agent_Brokerage__c>();

        Decimal totalBrokerageSum = 0;
        List<BrokerRow> brokerRows = new List<BrokerRow>();

        if (brokerages.isEmpty()) {
            wrapper.modeOfPayment = 'No Agent brokerage record is found';
            wrapper.isBrokerage = false;
        } else {
            wrapper.isBrokerage = true;
            List<String> brokerageStrings = new List<String>();

            for (Agent_Brokerage__c ab : brokerages) {
                totalBrokerageSum += (ab.Total_Bokerage__c != null) ? ab.Total_Bokerage__c : 0;
                brokerRows.add(new BrokerRow(
                    (ab.Account__r != null && ab.Account__r.Name != null) ? ab.Account__r.Name : ab.Name,
                    (ab.Account__r != null && ab.Account__r.Phone != null) ? formatPhone(ab.Account__r.Phone) : ''
                ));

                String vendorName = ab.Account__r?.Vendor_Name__c != null ? ab.Account__r.Vendor_Name__c : '';
                String accountName = ab.Account__r?.Name != null ? ab.Account__r.Name : ab.Name;
                String totalBrokerage = ab.Total_Bokerage__c != null ? String.valueOf(ab.Total_Bokerage__c.setScale(2)) : '0.00';
                String brokerageType = ab.Bokerage_Type__c != null ? ab.Bokerage_Type__c : '';

                brokerageStrings.add(vendorName + ' / ' + accountName + ' (' + totalBrokerage + ' ' + brokerageType + ')');
            }
            wrapper.modeOfPayment = String.join(brokerageStrings, ' | ');
        }
        
        wrapper.totalBrokerage = totalBrokerageSum;
        wrapper.brokerageList = brokerRows;
    }

    // --- Wrapper Classes ---
    public class ReportWrapper {
        public String currentDate { get; set; }
        public String project { get; set; }
        public String customerName { get; set; }
        public List<CoApplicantWrapper> coApplicants { get; set; }
        public String customerPan { get; set; }
        public String dateOfBirth { get; set; }
        public String codeNo { get; set; }
        public String address { get; set; }
        public String contactNo { get; set; }
        public String email { get; set; }
        public String bookingDate { get; set; }
        public String bookingRemarks { get; set; }
        public String unitNo { get; set; }
        public String tower { get; set; }
        public String type { get; set; }
        public String superBuiltUpArea { get; set; }
        public String floor { get; set; }
        public String terraceArea { get; set; }
        Public String carpetArea {get;set;}

        public Decimal grandTotal { get; set; }
        public Decimal totalLandConstPrice { get; set; }
        public Decimal totalOtherCost { get; set; }
        public String priceBreakup { get; set; }
        public Decimal payPlanDiscount { get; set; }
        public Decimal counterDiscount { get; set; }
        public Decimal totalBrokerage { get; set; }

        public String getPayPlanDiscountStr() { return String.valueOf(payPlanDiscount.setScale(2)); }
        public String getCounterDiscountStr() { return String.valueOf(counterDiscount.setScale(2)); }
        public String getTotalBrokerageStr() { return String.valueOf(totalBrokerage.setScale(2)); }

        public List<ChargeRow> saleConsideration { get; set; }
        public List<ChargeRow> otherCharges { get; set; }
        public Boolean isBrokerage { get; set; }
        public List<BrokerRow> brokerageList { get; set; }
        public String paymentPlan { get; set; }
        public String modeOfPayment { get; set; }
    }

    public class ChargeRow {
        public String accountHead { get; set; }
        public Decimal amount { get; set; }
        public String amountStr { get { return String.valueOf(amount.setScale(2)); } }
        public Boolean isTotal { get; set; }

        public ChargeRow(String head, Decimal amt) {
            accountHead = head;
            amount = amt;
            isTotal = false;
        }
        public ChargeRow(String head, Decimal amt, Boolean total) {
            accountHead = head;
            amount = amt;
            isTotal = total;
        }
    }

    public class BrokerRow {
        public String name { get; set; }
        public String contact { get; set; }

        public BrokerRow(String n, String c) {
            name = n;
            contact = c;
        }
    }
    
    public class CoApplicantWrapper {
        public Integer coApplicantNumber { get; set; }
        public String value { get; set; }
    
        public CoApplicantWrapper(Integer num, String val) {
            coApplicantNumber = num;
            value = val;
        }
    }

    // --- Phone Formatter ---
    public String formatPhone(String phone) {
        if (String.isBlank(phone)) return '-';
        String digits = phone.replaceAll('[^0-9]', '');
        if (digits.length() >= 10) digits = digits.right(10);
        return '+91 ' + digits.substring(0,5) + ' ' + digits.substring(5);
    }
}