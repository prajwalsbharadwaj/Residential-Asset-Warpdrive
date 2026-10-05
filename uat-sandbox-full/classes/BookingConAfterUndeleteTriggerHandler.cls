public class BookingConAfterUndeleteTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        BookingConditionHelper.recalcSiblingsIfBaseChanged(tp.newList, null);
    }
}