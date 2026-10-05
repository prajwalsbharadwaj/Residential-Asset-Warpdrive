public class SAPCustomerWrapper {
    public transient Id CUSTOMER_ID;
    public String businesspartner;
    public String role;
    public String bpRole1;
    public String bpRole2;
    public String bpgrouping;
    public String type;
    public String title;
    public String name1;
    public String middlename;
    public String langu;
    public String searchterm1;
    public String searchterm2;
    public String Street1;
    public String Street2;
    public String Street3;
    public String Street4;
    public String Postalcode;
    public String City;
    public String Country;
    public String Region;
    public String telephone1;
    public String mobile1;
    public String faxNo;
    public String email;
    public String taxnum1;
    public String compCode;
    public String recAcc;
    public String payTerm;
    public String pancard;
    public String salesorg;
    public String distributionchannel;
    public String division;
    public String salesDist; //000001, 000002, CENTRE, NORTH, SOUTH
    public String salesgroup;
    public String salesoffice; //same as sales org
    public String currencyCode;
    public String priceGroup;
    public String custpriceprocedure;
    public String vwerk;
    public String shipping;
    public String zterm;
    public String ktgrd;
    public String taxkd1;
    public String taxkd2;
    public String taxkd3;
    public String taxkd4;
    public String head_off_num;
    public String last_name;
    public String incoterms;
    public String incotermsloc; 
    public String joug;

    // Constructor to initialize default values
    public SAPCustomerWrapper() {
        this.role                 = '000000';
        this.bpRole1              = 'FLCU00';
        this.bpRole2              = 'FLCU01';
        this.bpgrouping           = 'C003';
        this.type                 = '1';
        //this.title                = '0002';
        this.langu                = 'EN';
        this.currencyCode         = 'INR';
        this.priceGroup           = '01';
        this.custpriceprocedure   = 'Z1';
        this.ktgrd                = 'Z1';
        this.zterm                = 'Z002';
        this.salesoffice          = '';    //Need to change. map salesOrg value
        this.payTerm              = '';    // Optional — can set if needed
        this.vwerk                = '';    // Optional
        this.head_off_num         = '';    // Optional
        this.incoterms            = '';    // new
        this.incotermsloc         = '';    // new
        this.joug         		  = '';    // new
        this.salesDist            = 'NORTH';
    }
}