public with sharing class LedgerConst {
    public static final String TYPE_INTEREST_ACCRUAL_BASIC = 'INTEREST_ACCRUAL_BASIC';
    public static final String TYPE_INTEREST_ACCRUAL_OTHER = 'INTEREST_ACCRUAL_OTHER';
    public static final String TYPE_INTEREST_TAX_ACCRUAL_BASIC = 'INTEREST_TAX_ACCRUAL_BASIC';
    public static final String TYPE_INTEREST_TAX_ACCRUAL_OTHER = 'INTEREST_TAX_ACCRUAL_OTHER';
    public static final String TYPE_PRINCIPAL_RECEIPT = 'PRINCIPAL_RECEIPT';
    public static final String TYPE_INTEREST_RECEIPT = 'INTEREST_RECEIPT';
    public static final String TYPE_INTEREST_TAX_RECEIPT = 'INTEREST_TAX_RECEIPT';
    public static final String TYPE_MANUAL_ADJUSTMENT = 'MANUAL_ADJUSTMENT';
    public static final String TYPE_REVERSAL = 'REVERSAL';
    public static final String TYPE_INTEREST_WAIVER = 'INTEREST_WAIVER';
    public static final String TYPE_INTEREST_TAX_WAIVER = 'INTEREST_TAX_WAIVER';

    public static final String BUCKET_BASIC = 'BASIC';
    public static final String BUCKET_OTHER = 'OTHER';

    public static final String SOURCE_ACCRUAL = 'ACCRUAL';
    public static final String SOURCE_RECEIPT = 'RECEIPT';
    public static final String SOURCE_REVERSAL = 'REVERSAL';
    public static final String SOURCE_ADJUSTMENT = 'ADJUSTMENT';

    public static final String STATUS_POSTED = 'POSTED';
    public static final String STATUS_REVERSED = 'REVERSED';
    public static final String STATUS_VOID = 'VOID';
}