public class QuoteBeforeInsertTriggerhandler extends TriggerHandlerBase {

    public override void mainEntry(TriggerParameters tp) {
        List<Quote> newList = (List<Quote>) tp.newList;
        
        ResQuoteTriggerHelper.markPrimaryQuote(newList);
    }
}