public class BookingPaySchedOtherChargesUpdateWrapper {
    public transient Id BOOKING_ID;
    public String booking;	//2010000076
	public String sales_grp;	//
	public String sales_off;	//
	public String sales_dist;	//
	public String purch_no_c;	//
	public String purch_date;	//
	public String price_grp;	//
	public String incoterms1;	//
	public String incoterms2;	//
	public String co_applicant1;	//
	public String co_applicant2;	//
	public String co_applicant3;	//
	public String co_applicant4;	//
	public String co_applicant5;	//
	public ItemWrapper[] item;
	public OtherItemWrapper[] otheritem;

	public class ItemWrapper {
		public String itm_number;	//10
		public String plant;	//2063
		public String material;	//R001-6281
		public String division;	//10
		public String reason_rej;	//
		public String cond;	//
		public BillWrapper[] bill;
	}
	public class BillWrapper {
		public String ITEM_NO;	//000003
		public String MILESTONE_CODE;	//Z0010
		public String MILESTONE_DES;	//PS-0003
		public String BILLING_DATE;	//2026-01-12
		public String INV_PER;	//80.00
		public String BILL_VAL;	//44716000.00
		public String BILL_RULE;	//2
		public String BILL_BLOCK;	//
	}
	public class OtherItemWrapper {
		public String itm_number;	//20
		public String plant;	//2063
		public String material;	//BESCOMANDBWSSB
		public String bill_block;	//
		public String billing_date;	//
	}

}