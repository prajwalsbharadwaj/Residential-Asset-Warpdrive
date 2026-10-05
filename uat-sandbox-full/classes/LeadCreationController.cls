/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : LeadCreationController
 * Author          : <YourName>
 * Created Date    : Apr 28, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Apr 28, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 28, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class LeadCreationController {
    
    @InvocableMethod(label='Create a Lead' description='Create a Lead using FullName, Email and Phone Number')
    public static List<Response> createLead(List<Request> request) {
        
        Filter filterObj = request[0].filterObj;
        	String name = filterObj.name;
        String email = filterObj.email;
        String phone = filterObj.phone;
        
        List<Response> responses = new List<Response>();
        List<Lead> leadsToInsert = new List<Lead>();
        
            try {
                // Create a new Lead record
                Lead newLead = new Lead(
                    FirstName = name.substringBefore(' '),
                    LastName = name.substringAfterLast(' '),
                    Email = email,
                    Phone = phone
                );
                
                leadsToInsert.add(newLead);
                
                // Add success message to the response
                Response res = new Response();
                res.leadResponse = new LeadResponse();
                res.leadResponse.message = 'Lead created successfully.';
                responses.add(res);
                
            } catch (Exception e) {
                // Add error message to the response
                Response res = new Response();
                res.leadResponse = new LeadResponse();
                res.leadResponse.message = 'Error creating lead: ' + e.getMessage();
                responses.add(res);
            }
        
        
        // DML operation
        if (!leadsToInsert.isEmpty()) {
            insert leadsToInsert; // Use partial success for multiple leads
        }
        
        return responses;
    }
    
    @JsonAccess(serializable='always' deserializable='always')
    public class Request {
      	 @InvocableVariable
        public Filter filterObj;
    }
    
    @JsonAccess(serializable='always' deserializable='always')
    public class Filter {
          @InvocableVariable(required=true)
        public String name;
        
        @InvocableVariable(required=true)
        public String email;
        
        @InvocableVariable(required=true)
        public String phone;
    }
    
    @JsonAccess(serializable='always' deserializable='always')
    public class Response {
        @InvocableVariable(required=true)
        public LeadResponse leadResponse;
    }
    
    @JsonAccess(serializable='always' deserializable='always')
    public class LeadResponse {
        @InvocableVariable(required=true)
        public String message;
    }
}