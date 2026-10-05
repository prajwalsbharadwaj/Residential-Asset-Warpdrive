@IsTest
private class TriggerFactoryAndDispatcherTest {

    /** 
     * A minimal test ITriggerHandler that records invocations.
     * Assumes your org already has the ITriggerHandler interface used by TriggerDispatcherBase.
     */
    private class TestHandler implements ITriggerHandler {
        Integer mainEntryCalls = 0;
        Integer inProgressCalls = 0;
        Integer updateObjectsCalls = 0;
        List<String> events = new List<String>();

        public void mainEntry(TriggerParameters tp) {
            mainEntryCalls++;
            events.add('main:' + (tp == null ? 'null' : 'ok'));
        }
        public void inProgressEntry(TriggerParameters tp) {
            inProgressCalls++;
            events.add('progress:' + (tp == null ? 'null' : 'ok'));
        }
        public void updateObjects() {
            updateObjectsCalls++;
            events.add('updateObjects');
        }
    }

    /**
     * A dispatcher that routes each event into TriggerDispatcherBase.execute(...)
     * twice: first with a fresh handler (to hit mainEntry + updateObjects), then
     * with null to exercise the "in-progress" path reusing cached handler.
     */
    private class TestDispatcher extends TriggerDispatcherBase implements ITriggerDispatcher {
        // Flags to confirm bulk & finally got called in the right phase
        Boolean sawBulkBefore = false;
        Boolean sawBulkAfter  = false;
        Boolean sawFinally    = false;

        private TriggerParameters lastTp;

        public override void bulkBefore() { sawBulkBefore = true; }
        public override void bulkAfter()  { sawBulkAfter  = true; }
        public override void andFinally() { sawFinally    = true; }

        public override void beforeInsert(TriggerParameters tp) {
            lastTp = tp;
            execute(new TestHandler(), tp, TriggerParameters.TriggerEvent.beforeInsert);
            execute(null, tp,            TriggerParameters.TriggerEvent.beforeInsert);
        }
        public override void beforeUpdate(TriggerParameters tp) {
            lastTp = tp;
            execute(new TestHandler(), tp, TriggerParameters.TriggerEvent.beforeUpdate);
            execute(null, tp,            TriggerParameters.TriggerEvent.beforeUpdate);
        }
        public override void beforeDelete(TriggerParameters tp) {
            lastTp = tp;
            execute(new TestHandler(), tp, TriggerParameters.TriggerEvent.beforeDelete);
            execute(null, tp,            TriggerParameters.TriggerEvent.beforeDelete);
        }

        public override void afterInsert(TriggerParameters tp) {
            lastTp = tp;
            execute(new TestHandler(), tp, TriggerParameters.TriggerEvent.afterInsert);
            execute(null, tp,            TriggerParameters.TriggerEvent.afterInsert);
        }
        public override void afterUpdate(TriggerParameters tp) {
            lastTp = tp;
            execute(new TestHandler(), tp, TriggerParameters.TriggerEvent.afterUpdate);
            execute(null, tp,            TriggerParameters.TriggerEvent.afterUpdate);
        }
        public override void afterDelete(TriggerParameters tp) {
            lastTp = tp;
            execute(new TestHandler(), tp, TriggerParameters.TriggerEvent.afterDelete);
            execute(null, tp,            TriggerParameters.TriggerEvent.afterDelete);
        }
        public override void afterUnDelete(TriggerParameters tp) {
            lastTp = tp;
            execute(new TestHandler(), tp, TriggerParameters.TriggerEvent.afterUnDelete);
            execute(null, tp,            TriggerParameters.TriggerEvent.afterUnDelete);
        }
    }

    /* ------------------------ Helpers ------------------------ */

    private static TriggerParameters makeTp() {
        // Construct a minimal TriggerParameters.
        // Assumes your org already has the TriggerParameters class with this constructor.
        // If it differs, adapt accordingly.
        return new TriggerParameters(
            new List<SObject>(),
            new List<SObject>{new Account()},
            new Map<Id, SObject>(),
            new Map<Id, SObject>(),
            true,  // isBefore (placeholder, not used inside TP)
            false, // isAfter
            false, // isDelete
            false, // isInsert
            false, // isUpdate
            false, // isUndelete
            true   // isExecuting
        );
    }

    private static void assertHandlerState() {
        // We can't get the static cached handlers directly,
        // but we can infer correct behavior because TestHandler increments per execute() call:
        // For each event, we call execute(handler) then execute(null) -> should produce 1 main + 1 progress + 1 updateObjects.
        // Across multiple events, those counts keep increasing.
        // Since we don't have direct access, our checks will focus on bulk/andFinally flags and
        // that no exceptions occur — indicating the cached path didn't blow up.
        // Additional deep inspection would require exposing counters via @TestVisible in the base.
    }

    /* ------------------------ Tests ------------------------ */

    @IsTest
    static void testBeforeInsertFlow_viaTestHook() {
        TestDispatcher d = new TestDispatcher();
        TriggerParameters tp = makeTp();

        Test.startTest();
        TriggerFactory.testExecute(d, tp,
            true,  // isBefore
            false, // isAfter
            false, // isDelete
            true,  // isInsert
            false, // isUpdate
            false  // isUndelete
        );
        Test.stopTest();

        System.assertEquals(true, d.sawBulkBefore, 'bulkBefore should run for before context.');
        System.assertEquals(false, d.sawBulkAfter,  'bulkAfter should not run in before context.');
        System.assertEquals(true, d.sawFinally,     'andFinally should always run.');
    }

    @IsTest
    static void testBeforeUpdateAndDelete_viaTestHook() {
        TestDispatcher d = new TestDispatcher();
        TriggerParameters tp = makeTp();

        Test.startTest();
        // before update
        TriggerFactory.testExecute(d, tp, true, false, false, false, true, false);
        // before delete
        TriggerFactory.testExecute(d, tp, true, false, true,  false, false, false);
        Test.stopTest();

        System.assertEquals(true, d.sawBulkBefore);
        System.assertEquals(true, d.sawFinally);
    }

    @IsTest
    static void testAfterInsertUpdateDelete_viaTestHook() {
        TestDispatcher d = new TestDispatcher();
        TriggerParameters tp = makeTp();

        Test.startTest();
        // after insert
        TriggerFactory.testExecute(d, tp, false, true, false, true,  false, false);
        // after update
        TriggerFactory.testExecute(d, tp, false, true, false, false, true,  false);
        // after delete
        TriggerFactory.testExecute(d, tp, false, true, true,  false, false, false);
        Test.stopTest();

        System.assertEquals(true, d.sawBulkAfter, 'bulkAfter should run for after context.');
        System.assertEquals(true, d.sawFinally);
    }

    @IsTest
    static void testAfterUndelete_viaTestHook() {
        TestDispatcher d = new TestDispatcher();
        TriggerParameters tp = makeTp();

        Test.startTest();
        TriggerFactory.testExecute(d, tp, false, true, false, false, false, true);
        Test.stopTest();

        System.assertEquals(true, d.sawBulkAfter);
        System.assertEquals(true, d.sawFinally);
    }

    @IsTest
    static void testFactoryNoDispatcher_throws() {
        // Using the hook with a null dispatcher should throw the same exception type
        // used in createTriggerDispatcher when no dispatcher is found.
        Boolean threw = false;
        try {
            TriggerFactory.testExecute(null, makeTp(),
                true, false, false, true, false, false);
        } catch (TriggerException ex) {
            threw = true;
            System.assert(ex.getMessage().contains('No Trigger dispatcher'), 'Should signal missing dispatcher.');
        }
        System.assertEquals(true, threw, 'Expected TriggerException when dispatcher is null.');
    }

    @IsTest
    static void testGetDispatcherTypeHook_createsInstance() {
        // Prove that the factory can instantiate a dispatcher type via Type API (matching its production approach).
        Type t = Type.forName('SiteVisitTriggerDispatcher');
        ITriggerDispatcher d = TriggerFactory.testMakeDispatcher(t);
        System.assertNotEquals(null, d, 'Dispatcher instance should be created from Type.');
    }
}