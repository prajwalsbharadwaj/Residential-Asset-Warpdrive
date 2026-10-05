/** Classifies inbound email cases as SIMPLE or COMPLEX for the Nikoo Homes Email Support Agent. */
trigger CaseClassificationTrigger on Case (before insert, before update) {
    ResiCaseClassifier.classify(Trigger.new);
}