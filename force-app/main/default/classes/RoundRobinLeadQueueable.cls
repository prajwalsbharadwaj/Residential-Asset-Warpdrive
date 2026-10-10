public class RoundRobinLeadQueueable implements Queueable {
    private List<Id> leadIds;

    public RoundRobinLeadQueueable(List<Id> leadIds) {
        this.leadIds = leadIds;
    }

    public void execute(QueueableContext ctx) {
        if (leadIds == null || leadIds.isEmpty()) return;
        for (Id leadId : leadIds) {
            try {
                RoundRobinActionController.assignLeadViaRoundRobin(leadId);
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Auto Round Robin assignment failed for lead ' + leadId + ': ' + ex.getMessage());
            }
        }
    }
}
