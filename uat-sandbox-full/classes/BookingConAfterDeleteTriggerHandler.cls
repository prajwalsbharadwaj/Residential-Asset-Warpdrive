public class BookingConAfterDeleteTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        BookingConditionHelper.recalcSiblingsOnDelete(tp.oldList);
    }
}