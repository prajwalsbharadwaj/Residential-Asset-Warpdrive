public class BookingSapPayloadBuilder {
    private static final String Token_Bill_Rule = SAPCodeTranslationUtil.getBillRuleMap().get('Milestone billing on a value basis');
    private static final String Token_Milestone_Code = SAPCodeTranslationUtil.getMilestoneCodeMap().get('Initial Token Advance');
    // Prepare JSON Body For SAP Payload
    public List<BookingWrapper> prepareJSONBodyForBooking(Set<Id> bookingIds) {
        //get bookingList.
        BookingSelector bookingSelector = new BookingSelector();
        list<Booking__c> bookingList = bookingSelector.getBookingByIds(bookingIds);

        List<BookingWrapper> payloadList = new List<BookingWrapper>();
        //map to store label vs cmdt record for handling picklist values of booking conditions.
        map<String, ConditionTypeCode__mdt> ConditionTypeCodesMap = new Map<string, ConditionTypeCode__mdt>();
        
        list<ConditionTypeCode__mdt> conditionTypeList = [SELECT DeveloperName, Label, Unit_External_ID__c, Sync_with_SAP__c, UOM__c, Type__c FROM ConditionTypeCode__mdt];
        system.debug('conditionTypeList--> ' + conditionTypeList);
        
        for (ConditionTypeCode__mdt mdt : conditionTypeList) {
            ConditionTypeCodesMap.put(mdt.Label, mdt);
        }
        system.debug('conditionsTypeCodes--> ' + ConditionTypeCodesMap);

        for (Booking__c b : bookingList) {
            BookingWrapper wrapper = new BookingWrapper();
            wrapper.BOOKING_ID = b.Id;
            wrapper.PARTNER1 = b.Account_Id__r?.SAP_External_Id__c;
            wrapper.PARTNER2 = b.Co_Applicant_1__r?.SAP_External_Id__c;
            wrapper.PARTNER3 = b.Co_Applicant_2__r?.SAP_External_Id__c;
            wrapper.PARTNER4 = b.Co_Applicant_3__r?.SAP_External_Id__c;
            wrapper.PARTNER5 = b.Co_Applicant_4__r?.SAP_External_Id__c;
            wrapper.PARTNER6 = b.Co_Applicant_5__r?.SAP_External_Id__c;
            wrapper.Payment_Plan = b.Payment_Plan_Id__r?.Name;
            wrapper.CUSTOMER_REF = b.SFDC_Booking_Reference_No__c;
            wrapper.CUST_REF_DATE = (b.Booking_Date__c != null) ? String.valueOf(b.Booking_Date__c) : null;
            wrapper.SALES_ORG = SAPCodeTranslationUtil.getSalesOrgMap().get(b.Sales_Organization__c);
            wrapper.DOCUMENT_TYPE = SAPCodeTranslationUtil.getDocumentTypeMap().get(b.Document_Type__c);
            wrapper.DIVISION = SAPCodeTranslationUtil.getDivisionMap().get(b.Division__c);
            wrapper.DIST_CHANNEL = SAPCodeTranslationUtil.getDistributionChannelMap().get(b.Distribution_Channel__c);

            // Prepare ITEM List
            List<BookingWrapper.ItemWrapper> itemList = new List<BookingWrapper.ItemWrapper>();
            Map<Id, Booking_Condition__c> conditionMap = new Map<Id, Booking_Condition__c>();
            BookingWrapper.ItemWrapper basePriceItem = new BookingWrapper.ItemWrapper();
            for(Booking_Condition__c condition : b.Booking_Conditions__r){
                BookingWrapper.ItemWrapper item;
                if(condition.Condition_Type__c == 'Base Price'){
                    item = basePriceItem;
                }else If(condition.Condition_Type__c == 'Base Price Discount'){
                    basePriceItem.COND2 = ConditionTypeCodesMap.get(condition.Condition_Type__c).developerName;
                    basePriceItem.PRICE2 = String.valueOf(condition.Amount__c);
                    continue;
                }else{
                    item = new BookingWrapper.ItemWrapper();
                }
                //item.PLANT_CODE = b.Unit_Id__r.Tower__r.SAP_External_Id__c;
                item.PLANT_CODE = SAPCodeTranslationUtil.getTowerExternalId(b.Unit_Id__r?.Tower__r?.SAP_External_Id__c);
                item.COND1 = ConditionTypeCodesMap.get(condition.Condition_Type__c).developerName;
                
                List<BookingWrapper.BillWrapper> billList = new List<BookingWrapper.BillWrapper>();

                if (condition.Condition_Type__c == 'Base Price'){
                    item.UOM = condition.UOM__c;
                    item.MATERIAL = b.Unit_Id__r?.SAP_External_Id__c;
                    item.QTY = String.valueOf(condition.Quantity__c);
                    item.ZWBS_STRUCTURE = b.Unit_Id__r?.Tower__r?.ZWBS_Structure__c;
                    item.PRICE1 = String.valueOf(condition.Amount__c);
                    
                    integer counter = 1;
                    // Prepare BILL List
                    for( Booking_Payment_Schedule__c BPS : b.Booking_Payment_Schedules__r){
                        BookingWrapper.BillWrapper bill = new BookingWrapper.BillWrapper();
                        Decimal billValue = (BPS.Adjusted_Amount__c != null) ? BPS.Adjusted_Amount__c : BPS.Installment_Amount__c;
                        
                        if(bps.Milestone_Code__c == 'Initial Token Advance' && bps.Installment_Amount__c > 0){
                            bill.ITEM_NO = String.valueOf(counter++*10);
                            bill.BILLING_DATE = String.valueOf(BPS.Payment_Due_Date__c);
                            bill.BILL_VAL = String.valueOf(billValue);
                            bill.BILL_BLOCK = SAPCodeTranslationUtil.getBillBlockMap().get(BPS.Bill_Block__c);
                            bill.BILL_RULE = Token_Bill_Rule;
                            bill.MILESTONE_CODE = Token_Milestone_Code;
                            billList.add(bill);
                        }else if(bps.Milestone_Code__c != 'Initial Token Advance' && bps.Milestone_Code__c != 'Other Charges'){
                            bill.ITEM_NO = String.valueOf(counter++*10);
                            bill.BILLING_DATE = String.valueOf(BPS.Payment_Due_Date__c);
                            bill.INV_PER = String.valueOf(BPS.Payment_Schedule_Id__r.Payment_Percentage__c);
                            bill.BILL_VAL = String.valueOf(billValue);
                            bill.BILL_BLOCK = SAPCodeTranslationUtil.getBillBlockMap().get(BPS.Bill_Block__c);
                            bill.BILL_RULE = SAPCodeTranslationUtil.getBillRuleMap().get(BPS.Payment_Schedule_Id__r?.Billing_Rule__c);//Token_Bill_Rule;
                            bill.MILESTONE_CODE = SAPCodeTranslationUtil.getMilestoneCodeMap().get(BPS.Payment_Schedule_Id__r.Milestone_Code__c);
                            
                            if(bps.Milestone_Code__c == 'On Possession'){
                                bill.BILL_VAL = String.valueOf(billValue - b.Opportunity_Id__r.OtherCharges__c - b.Opportunity_Id__r.TaxOnOtherCharges__c);
                            }
                            billList.add(bill);
                        }
                    }
                } else {
                    
                    ConditionTypeCode__mdt conditionTypeMetadata = ConditionTypeCodesMap.get(condition.Condition_Type__c);
                    if(conditionTypeMetadata.Sync_with_SAP__c == false) continue;
                    system.debug('Unit External Id--> ' + conditionTypeMetadata.Unit_External_ID__c);
                    item.MATERIAL = conditionTypeMetadata?.Unit_External_ID__c;
                    item.QTY = string.valueOf(condition.Quantity__c);
                    item.UOM = condition.UOM__c;
                    //Updated on 16 Dec, 2025 by Prince
                    //Setting default value as asked by SAP team, it was not told previously 
                    item.BILL_BLOCK_ITEM = SAPCodeTranslationUtil.getBillBlockMap().get('Compl Confirm Missng'); 
                    if(conditionTypeMetadata.Type__c == 'Percentage'){
                        item.PRICE1 = String.valueOf(condition.Percentage__c);
                    }else if(conditionTypeMetadata.Type__c == 'Fixed Amount'){
                        item.PRICE1 = String.valueOf(condition.Amount__c);
                    }else if(conditionTypeMetadata.Type__c == 'Rate'){
                        item.PRICE1 = String.valueOf(condition.Amount_By_Type__c);
                    }
                }
                item.BILL = billList;
                itemList.add(item);
            }
            //itemList.sort();

            Integer counter = 10;
            for (BookingWrapper.ItemWrapper item : itemList) {
                item.POSNR = counter;
                counter += 10;
            }
            wrapper.ITEM = itemList;
            payloadList.add(wrapper);
            System.debug('Payload JSON--> ' + JSON.serialize(wrapper));
        }
        return payloadList;
    }
    
    // Building payload when booking condition records changes.
    public list<BookingUpdateWrapper> jsonBodyForBookingConditionUpdate(set<id> bookingIds, set<Id> bookingConditionIds){
        
        //Get Bookings
        BookingSelector bookingSelector = new BookingSelector();
        list<Booking__c> bookingList = bookingSelector.getBookingByIds(bookingIds);
        
        //Get Booking Conditions
       BookingConditionService bcService = new BookingConditionService();
       map<Id,list<booking_Condition__c>> bcMap = bcService.getBookingConditionsByBookingIds(bookingConditionIds);
    
    //get custom metadata record for booking condition type codes.
    map<String, ConditionTypeCode__mdt> ConditionTypeCodesMap = new Map<string, ConditionTypeCode__mdt>();
    list<ConditionTypeCode__mdt> conditionTypeList = [SELECT DeveloperName, Label, Unit_External_ID__c FROM ConditionTypeCode__mdt];
    for (ConditionTypeCode__mdt mdt : conditionTypeList) {
      ConditionTypeCodesMap.put(mdt.Label, mdt);
    }
    system.debug('conditionsTypeCodes--> ' + ConditionTypeCodesMap);        
        
        list<BookingUpdateWrapper> payLoadList = new list<BookingUpdateWrapper>();
        for(Booking__c b:bookingList){
            //Prepare BookingUpdateWrapper
            BookingUpdateWrapper wrapper = new BookingUpdateWrapper();
            wrapper.BOOKING_ID = b.Id;
            wrapper.booking = b?.SAP_External_Id__c;
            wrapper.sales_off = SAPCodeTranslationUtil.getSalesOrgMap().get(b.Sales_Organization__c);
            wrapper.co_applicant1 = b.Co_Applicant_1__r?.SAP_External_Id__c;
            wrapper.co_applicant2 = b.Co_Applicant_2__r?.SAP_External_Id__c;
            wrapper.co_applicant3 = b.Co_Applicant_3__r?.SAP_External_Id__c;
            wrapper.co_applicant4 = b.Co_Applicant_4__r?.SAP_External_Id__c;
            wrapper.co_applicant5 = b.Co_Applicant_5__r?.SAP_External_Id__c;
            
            //Prepare items
            list<BookingUpdateWrapper.ItemWrapper> itemList = new list<BookingUpdateWrapper.ItemWrapper>();
            BookingUpdateWrapper.ItemWrapper item = new BookingUpdateWrapper.ItemWrapper();
            item.itm_number = '10';
            item.material = b.Unit_Id__r?.SAP_External_Id__c;
            //item.reason_rej = ?
            item.plant = b.Unit_Id__r?.Property__r?.SAP_External_Id__c;
            item.division = SAPCodeTranslationUtil.getDivisionMap().get(b.Division__c);
            
            list<BookingUpdateWrapper.ConditionWrapper> conditionWrapList = new list<BookingUpdateWrapper.ConditionWrapper>();
            for(Booking_condition__c bc: bcMap.get(b.Id)){
                BookingUpdateWrapper.ConditionWrapper condWrapper = new BookingUpdateWrapper.ConditionWrapper();
                condWrapper.itm_number = string.valueOf(bc.Item_Number__c);
                condWrapper.cond_type = ConditionTypeCodesMap.get(bc.Condition_Type__c).developerName;
                condWrapper.cond_value = string.valueOf(bc.Amount__c);
                conditionWrapList.add(condWrapper);
            }
            item.cond = conditionWrapList;
            itemList.add(item);
            wrapper.item = itemList;
            payLoadList.add(wrapper);
        }
        system.debug('Json Body Booking Condition Update--> '+JSON.serialize(payloadList));
        return payLoadList;
    }
    
    // Building payload when booking payment schedule records changes.
    public list<BookingUpdateWrapper> jsonBodyForBookingPaymentScheduleUpdate(set<id> bookingIds, set<Id> bookingPaymentSchIds){
        //Get Bookings.
        BookingSelector bookingSelector = new BookingSelector();
        list<Booking__c> bookingList = bookingSelector.getBookingByIds(bookingIds);
        
        //Get Booking Payment Schedules.
        BookingPaymentScheduleService bpsService = new BookingPaymentScheduleService();
        
        //get all booking payment schedules of booking
        //sorted by installment number in ascending order
        Map<Id, List<Booking_Payment_Schedule__c>> bpsMap = bpsService.getBookingPaymentSchedulesByBookingIds(bookingIds);
        system.debug('bpsMap--> '+ JSON.Serialize(bpsMap));
        
        list<BookingUpdateWrapper> payLoadList = new list<BookingUpdateWrapper>();
        for(Booking__c b:bookingList){
            //Prepare BookingUpdateWrapper
            BookingUpdateWrapper wrapper = new BookingUpdateWrapper();
            wrapper.BOOKING_ID = b.Id;
            wrapper.booking = b?.SAP_External_Id__c;
            wrapper.co_applicant1 = b.Co_Applicant_1__r?.SAP_External_Id__c;
            wrapper.co_applicant2 = b.Co_Applicant_2__r?.SAP_External_Id__c;
            wrapper.co_applicant3 = b.Co_Applicant_3__r?.SAP_External_Id__c;
            wrapper.co_applicant4 = b.Co_Applicant_4__r?.SAP_External_Id__c;
            wrapper.co_applicant5 = b.Co_Applicant_5__r?.SAP_External_Id__c;
            
            //Prepare items
            list<BookingUpdateWrapper.ItemWrapper> itemList = new list<BookingUpdateWrapper.ItemWrapper>();
            BookingUpdateWrapper.ItemWrapper item = new BookingUpdateWrapper.ItemWrapper();
            item.itm_number = '10';
            item.material = b.Unit_Id__r?.SAP_External_Id__c;
            //item.reason_rej = ?
            item.plant = SAPCodeTranslationUtil.getTowerExternalId(b.Unit_Id__r?.Tower__r?.SAP_External_Id__c);
            item.division = SAPCodeTranslationUtil.getDivisionMap().get(b.Division__c);
            
            list<BookingUpdateWrapper.BillingWrapper> billWrapList = new list<BookingUpdateWrapper.BillingWrapper>();
            integer counter = 1;
            for(Booking_Payment_Schedule__c bps:bpsMap.get(b.Id)){
                
                if(!bookingPaymentSchIds.contains(bps.Id)){
                    counter++;
                    continue;
                }
                
                BookingUpdateWrapper.BillingWrapper bill = new BookingUpdateWrapper.BillingWrapper();
                if(bps.Milestone_Code__c == 'Initial Token Advance' && bps.Installment_Amount__c > 0){
                    bill.ITEM_NO = '00000' + counter++;//string.valueOf(bps.Installment_Number__c * 10);
                    bill.BILLING_DATE = string.valueOf(Date.today());//string.valueOf(bps.Payment_Due_Date__c);
                    bill.BILL_VAL = string.valueOf(bps.Installment_Amount__c);
                    bill.BILL_BLOCK = SAPCodeTranslationUtil.getBillBlockMap().get(bps.Bill_Block__c) ?? '';
                    bill.BILL_RULE = Token_Bill_Rule;
                    bill.MILESTONE_CODE = Token_Milestone_Code;
                    bill.MILESTONE_DES = bps.Milestone_Code__c;
                    billWrapList.add(bill);
                }else if(bps.Milestone_Code__c != 'Initial Token Advance'){
                    bill.ITEM_NO = '00000' + counter++;//string.valueOf(bps.Installment_Number__c * 10);
                    bill.BILLING_DATE = string.valueOf(Date.today());//string.valueOf(bps.Payment_Due_Date__c);
                    bill.INV_PER = string.valueOF(bps.Payment_Schedule_Id__r.Payment_Percentage__c);
                    bill.BILL_VAL = string.valueOf(bps.Installment_Amount__c);
                    bill.BILL_BLOCK = SAPCodeTranslationUtil.getBillBlockMap().get(bps.Bill_Block__c) ?? '';
                    bill.BILL_RULE = SAPCodeTranslationUtil.getBillRuleMap().get(bps.Payment_Schedule_Id__r?.Billing_Rule__c);
                    bill.MILESTONE_CODE = SAPCodeTranslationUtil.getMilestoneCodeMap().get(bps.Payment_Schedule_Id__r.Milestone_Code__c);
                    bill.MILESTONE_DES = bps.Payment_Schedule_Id__r.Name;
                    billWrapList.add(bill);
                }
            }
            item.bill = billWrapList;
            itemList.add(item);
            wrapper.item = itemList;
            payLoadList.add(wrapper);//
        }
        system.debug('Json Body Booking Payment Schedule Update--> '+JSON.serialize(payloadList));
        return payLoadList;
    }

    public list<BookingPaySchedOtherChargesUpdateWrapper> jsonBodyForOtherchargesBookingPaymentScheduleUpdate(set<id> bookingIds, set<Id> bookingPaymentSchIds){
        //Get Bookings.
        BookingSelector bookingSelector = new BookingSelector();
        list<Booking__c> bookingList = bookingSelector.getBookingByIds(bookingIds);
        
        //Get Booking Payment Schedules.
        BookingPaymentScheduleService bpsService = new BookingPaymentScheduleService();
        
        //get all booking payment schedules of booking
        //sorted by installment number in ascending order
        Map<Id, List<Booking_Payment_Schedule__c>> bpsMap = bpsService.getBookingPaymentSchedulesByBookingIds(bookingIds);
        system.debug('bpsMap--> '+ JSON.Serialize(bpsMap));
        
        map<String, ConditionTypeCode__mdt> ConditionTypeCodesMap = new Map<string, ConditionTypeCode__mdt>();
        list<ConditionTypeCode__mdt> conditionTypeList = [SELECT DeveloperName, Label, Unit_External_ID__c, Sync_with_SAP__c FROM ConditionTypeCode__mdt];
        for (ConditionTypeCode__mdt mdt : conditionTypeList) {
            ConditionTypeCodesMap.put(mdt.Label, mdt);
        }

        list<BookingPaySchedOtherChargesUpdateWrapper> payLoadList = new list<BookingPaySchedOtherChargesUpdateWrapper>();
        for(Booking__c b:bookingList){
            //Prepare BookingPaySchedOtherChargesUpdateWrapper
            BookingPaySchedOtherChargesUpdateWrapper wrapper = new BookingPaySchedOtherChargesUpdateWrapper();
            wrapper.BOOKING_ID = b.Id;
            wrapper.booking = b?.SAP_External_Id__c;
            wrapper.co_applicant1 = b.Co_Applicant_1__r?.SAP_External_Id__c;
            wrapper.co_applicant2 = b.Co_Applicant_2__r?.SAP_External_Id__c;
            wrapper.co_applicant3 = b.Co_Applicant_3__r?.SAP_External_Id__c;
            wrapper.co_applicant4 = b.Co_Applicant_4__r?.SAP_External_Id__c;
            wrapper.co_applicant5 = b.Co_Applicant_5__r?.SAP_External_Id__c;
            
            //Prepare items
            list<BookingPaySchedOtherChargesUpdateWrapper.ItemWrapper> itemList = new list<BookingPaySchedOtherChargesUpdateWrapper.ItemWrapper>();
            BookingPaySchedOtherChargesUpdateWrapper.ItemWrapper item = new BookingPaySchedOtherChargesUpdateWrapper.ItemWrapper();
            item.itm_number = '10';
            item.material = b.Unit_Id__r?.SAP_External_Id__c;
            //item.reason_rej = ?
            item.plant = SAPCodeTranslationUtil.getTowerExternalId(b.Unit_Id__r?.Tower__r?.SAP_External_Id__c);
            item.division = SAPCodeTranslationUtil.getDivisionMap().get(b.Division__c);
            
            itemList.add(item);
            wrapper.item = itemList;

            list<BookingPaySchedOtherChargesUpdateWrapper.OtherItemWrapper> otherItemWrapList = new list<BookingPaySchedOtherChargesUpdateWrapper.OtherItemWrapper>();
            Integer counter = 10;
            
            for(Booking_Condition__c condition : b.Booking_Conditions__r){

                if (condition.Condition_Type__c == 'Base Price'){
                    
                } else {
                    BookingPaySchedOtherChargesUpdateWrapper.OtherItemWrapper otherItem = new BookingPaySchedOtherChargesUpdateWrapper.OtherItemWrapper();
                    
                    ConditionTypeCode__mdt conditionTypeMetadata = ConditionTypeCodesMap.get(condition.Condition_Type__c);
                    if(conditionTypeMetadata.Sync_with_SAP__c == false) continue;
                    system.debug('Unit External Id--> ' + conditionTypeMetadata.Unit_External_ID__c);
                    otherItem.itm_number = counter + '';
                    otherItem.material = conditionTypeMetadata?.Unit_External_ID__c;
                    otherItem.plant = SAPCodeTranslationUtil.getTowerExternalId(b.Unit_Id__r?.Tower__r?.SAP_External_Id__c);
                    otherItem.bill_block = '';
                    otherItem.billing_date = DateTime.now().format('dd.MM.yyyy');//string.valueOf(Date.today());
                    otherItemWrapList.add(otherItem);
                }
                counter +=10;
                
            }
            
            wrapper.otheritem = otherItemWrapList;
            
            payLoadList.add(wrapper);//
        }
        system.debug('Json Body Booking Payment Schedule other charges Update--> '+JSON.serialize(payloadList));
        return payLoadList;
    }
    
     //Building Payload for Booking Update callout which will trigger when Co-Applicant is changed on Booking record.
    public list<BookingUpdateWrapper> jsonBodyForCoApplicantUpdate(set<Id> bookingIds){
        //Get Bookings.
        BookingSelector bookingSelector = new BookingSelector();
        list<Booking__c> bookingList = bookingSelector.getBookingByIds(bookingIds);
        
        list<BookingUpdateWrapper> payLoadList = new list<BookingUpdateWrapper>();
        for(Booking__c b:bookingList){
            //Prepare BookingUpdateWrapper
            BookingUpdateWrapper wrapper = new BookingUpdateWrapper();
            wrapper.BOOKING_ID = b.Id;
            wrapper.booking = b?.SAP_External_Id__c;
            wrapper.co_applicant1 = b.Co_Applicant_1__r?.SAP_External_Id__c;
            wrapper.co_applicant2 = b.Co_Applicant_2__r?.SAP_External_Id__c;
            wrapper.co_applicant3 = b.Co_Applicant_3__r?.SAP_External_Id__c;
            wrapper.co_applicant4 = b.Co_Applicant_4__r?.SAP_External_Id__c;
            wrapper.co_applicant5 = b.Co_Applicant_5__r?.SAP_External_Id__c;
            //Prepare items
            list<BookingUpdateWrapper.ItemWrapper> itemList = new list<BookingUpdateWrapper.ItemWrapper>();
            BookingUpdateWrapper.ItemWrapper item = new BookingUpdateWrapper.ItemWrapper();
            item.itm_number = '10';
            item.material = b.Unit_Id__r?.SAP_External_Id__c;
            //item.plant = b.Unit_Id__r?.Tower__r?.SAP_External_Id__c;
            item.plant = SAPCodeTranslationUtil.getTowerExternalId(b.Unit_Id__r?.Tower__r?.SAP_External_Id__c);
            item.division = SAPCodeTranslationUtil.getDivisionMap().get(b.Division__c);
            itemList.add(item);
            wrapper.ITEM = itemList;
            payLoadList.add(wrapper);
        }
        system.debug('Json Body Co-Applicant Update--> '+JSON.serialize(payloadList));
        return payLoadList;
    }
}