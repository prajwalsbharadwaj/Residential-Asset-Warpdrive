({
    invoke : function(component, event, helper) {
        // 1. Get the Lead ID passed from the Flow
        var leadId = component.get("v.recordId");
        
        console.log('Aura Action: Hard Redirecting to Lead ID: ' + leadId);

        if (leadId) {
            // 2. We use window.parent.location.href
            // This is the most powerful way to break out of a Flow and 
            // force the browser to go to the Lead record page.
            var url = '/lightning/r/Lead/' + leadId + '/view';
            window.parent.location.href = url;
        } else {
            console.error("NavigateToLead Error: No recordId was passed.");
        }
    }
})