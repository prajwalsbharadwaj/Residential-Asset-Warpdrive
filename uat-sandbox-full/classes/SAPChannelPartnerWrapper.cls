public class SAPChannelPartnerWrapper {
    public String PARTNER;
    public String TITLE { get; set; }
    public String KTOKK { get; set; }
    public String NAME_ORG1 { get; set; }
    public String NAME_ORG2 { get; set; }
    public String NAME_ORG3 { get; set; }
    public String SORTL { get; set; }
    public String STRAS { get; set; }
    public String STR_SUPPL1 { get; set; }
    public String STR_SUPPL2 { get; set; }
    public String STR_SUPPL3 { get; set; }
    public String STR_SUPPL4 { get; set; }
    public String PSTLZ { get; set; }
    public String MCOD3 { get; set; }
    public String LAND1 { get; set; }
    public String REGIO { get; set; }
    public String SPRAS { get; set; }
    public String TEL_NUMBER { get; set; }
    public String MOB_NUMBER { get; set; }
    public String SMTP_ADDR { get; set; }
    public String TAXTYPE { get; set; }
    public String TAXNUMXL { get; set; }
    public String J_1IPANNO { get; set; }
    public String BANKS { get; set; }
    public String BANKL { get; set; }
    public String BANKN { get; set; }
    public String ACCNAME { get; set; }
    public String WT_TYPE { get; set; }
    public String WT_CODE { get; set; }
    public String LOWER_DED_CERT_NO { get; set; }
    public String AKONT { get; set; }
    public String REPRF { get; set; }
    public String RENA_NUMBER { get; set; }
    public String RERA_VALID_FROM { get; set; }
    public String RERA_VALID_TO { get; set; }

    public SAPChannelPartnerWrapper() {
        this.TITLE = '0003';
        this.KTOKK = 'V001';
        this.LAND1 = 'IN';
        this.SPRAS = 'EN';
        this.AKONT = '23200000';
        this.TAXTYPE = 'IN3';
        this.LAND1 = 'IN';
        this.REPRF = 'X';
    }
}