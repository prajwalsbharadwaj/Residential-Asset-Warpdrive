({
    doInit : function(component, event, helper) {
        
        var action = component.get("c.clickToCall");
        action.setParams({ 'recordId' : component.get("v.recordId") }); 
        action.setCallback(this, function(response) {
            console.log('');
            var state = response.getState();
            if (state === "SUCCESS") {
                 var toastEvent = $A.get("e.force:showToast");
    				toastEvent.setParams({
        			"title": "Success!",
        			"message": "Call initiation successful. You will be connected shortly.",
                     "type":"success"
    				});
    			toastEvent.fire();
                
                
                $A.get("e.force:closeQuickAction").fire();
                

                component.set("v.Ids",response.getReturnValue()); 
            } 
        });  
        $A.enqueueAction(action); 

    }
})