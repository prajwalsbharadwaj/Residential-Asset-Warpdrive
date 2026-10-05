public class DemandLetterNotifyScheduler implements schedulable {
    
    public void execute(schedulableContext sc){
        Date next15Days = Date.today() + 15;
        list<Booking_Payment_Schedule__c> bpsList = [SELECT Id, Payment_Due_Date__c, owner.Email, Booking__r.Name,Installment_Amount__c,
                                                     Booking__r.Owner.FirstName,Booking__r.owner.Email,
                                                     (SELECT Id,DemandLetterSentDate__c FROM Demands__r WHERE DemandLetterSentDate__c = null) 
                                                     FROM Booking_Payment_Schedule__c WHERE Payment_Due_Date__c =:next15Days];
        system.debug('bpsList '+bpsList);
        list<Messaging.SingleEmailMessage> mailList = new list<Messaging.SingleEmailMessage>();
        list<Task> tList = new list<Task>();
        String template = loadEmailTemplate('demandLetterNotification');
        for(Booking_Payment_Schedule__c bps:bpsList){
            if (bps.Demands__r.isEmpty()) continue;
            for(Demand__c d:bps.Demands__r){
                system.debug('DEMAND-> '+ bps.Demands__r);
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                // Recipient
                mail.setToAddresses(new String[] { bps.Booking__r.owner.Email });
                
                // Subject
                mail.setSubject('Demand Letter Due by '+ formattedDate(bps.Payment_Due_Date__c) + ' – Booking: '+bps.Booking__r.Name);
                
                // Enable HTML
                mail.setHtmlBody(getDemandLetterEmailBody(bps, d, template));
                
                // Send the email
                mailList.add(mail);
                
                //create task for booking owner.
                Task t = new Task();
                t.ActivityDate = bps.Payment_Due_Date__c;
                t.Description = 'Please generate the demand letter for this payment milestone.';
                t.OwnerId = bps.Booking__r.ownerId;
                t.Priority = 'Normal';
                t.Status = 'Not Started';
                t.Subject = 'Reminder: Generate Demand Letter';
                t.WhatId = bps.Id;
                tList.add(t);
            }
        }
        if(!mailList.isEmpty()){
            Messaging.sendEmail(mailList);
        }
        if(!tList.isEmpty()){
            insert tList;
        }
    }
    
    public static String formattedDate(Date inputDate) {
        if (inputDate == null) return '';
        
        // Convert Date → DateTime
        DateTime dt = DateTime.newInstance(inputDate, Time.newInstance(0, 0, 0, 0));
        
        // Format using DateTime.format()
        return dt.format('dd - MMM - yyyy');
    }
    
    public static String getDemandLetterEmailBody(Booking_Payment_Schedule__c bps,Demand__c demand, String template) {
        
        // Format your fields
        String ownerName = bps.Booking__r.Owner.FirstName;
        String bookingName = bps.Booking__r.Name;
        String formattedDueDate = formattedDate(bps.Payment_Due_Date__c);
        String amount = String.valueOf(bps.Installment_Amount__c);
        String recordLink = System.Url.getOrgDomainUrl().toExternalForm() + '/' + bps.Id;
        
        // Replace placeholders
        template = template.replace('{!$Record.Booking__r.Owner:User.FirstName}', ownerName);
        template = template.replace('{!$Record.Booking__r.Name}', bookingName);
        template = template.replace('{!formattedDueDate}', formattedDueDate);
        template = template.replace('{!$Record.Installment_Amount__c}', amount);
        template = template.replace('{!recordLink}', recordLink);
        
        return template;
    }
    
    
    public static String loadEmailTemplate(string resourceName){
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name =: resourceName];
        System.debug('Static Resource Body Length --> ' + sr.Body.toString().length());
        return sr.Body.toString();
    }
    
}