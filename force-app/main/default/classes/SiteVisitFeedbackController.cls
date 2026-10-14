/**
 * @description Controller for the interactive Site Visit Add Feedback modal.
 *              Captures Customer Details, Voice of Customer, and Sales Executive Deal Intelligence
 *              with zero-scroll, high-density layout and dynamic interest level slider.
 */
public without sharing class SiteVisitFeedbackController {

    public class SiteVisitDetailDTO {
        @AuraEnabled public Id siteVisitId { get; set; }
        @AuraEnabled public String siteVisitName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerMobile { get; set; }
        @AuraEnabled public String customerEmail { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public Id unitId { get; set; }
        @AuraEnabled public String floorName { get; set; }
        @AuraEnabled public String buildingName { get; set; }
        @AuraEnabled public String configuration { get; set; }
        @AuraEnabled public Datetime visitDateTime { get; set; }
        @AuraEnabled public String rating { get; set; } // Hot, Warm, Cold
        @AuraEnabled public String interestLevel { get; set; } // High, Medium, Low, No Interest
        @AuraEnabled public Integer interestPercent { get; set; } // 0 - 100
        @AuraEnabled public String overallExperience { get; set; } // Superior, Good, Average, Poor
        @AuraEnabled public String likedProduct { get; set; } // Project, Product
        @AuraEnabled public String visitedShowFlat { get; set; } // Yes, No
        @AuraEnabled public String visitedWithFamily { get; set; } // Yes, No
        @AuraEnabled public String recommendFriends { get; set; } // Yes, No
        @AuraEnabled public String nextFollowUp { get; set; } // Week, Fortnight
        @AuraEnabled public String customerComments { get; set; }
        @AuraEnabled public String executiveRemarks { get; set; }
        @AuraEnabled public String salesManagerRemarks { get; set; }
        @AuraEnabled public String quickTags { get; set; }
        @AuraEnabled public Id closingManagerId { get; set; }
        @AuraEnabled public String closingManagerName { get; set; }
        @AuraEnabled public List<UserOption> closingManagers { get; set; }
    }

    public class UserOption {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String title { get; set; }
    }

    public class FeedbackSaveRequest {
        @AuraEnabled public Id siteVisitId { get; set; }
        @AuraEnabled public String rating { get; set; }
        @AuraEnabled public String interestLevel { get; set; }
        @AuraEnabled public Integer interestPercent { get; set; }
        @AuraEnabled public String overallExperience { get; set; }
        @AuraEnabled public String likedProduct { get; set; }
        @AuraEnabled public String visitedShowFlat { get; set; }
        @AuraEnabled public String visitedWithFamily { get; set; }
        @AuraEnabled public String recommendFriends { get; set; }
        @AuraEnabled public String nextFollowUp { get; set; }
        @AuraEnabled public String customerComments { get; set; }
        @AuraEnabled public String executiveRemarks { get; set; }
        @AuraEnabled public String salesManagerRemarks { get; set; }
        @AuraEnabled public String quickTags { get; set; }
        @AuraEnabled public Id closingManagerId { get; set; }
        @AuraEnabled public String status { get; set; } // 'Completed'
    }

    public class SaveResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id siteVisitId { get; set; }
        @AuraEnabled public String updatedStatus { get; set; }
    }

    /**
     * @description Fetches all existing site visit, customer, and project details to pre-populate the modal.
     */
    @AuraEnabled(cacheable=true)
    public static SiteVisitDetailDTO getSiteVisitDetails(Id siteVisitId) {
        if (siteVisitId == null) {
            throw new AuraHandledException('Site Visit ID is required');
        }

        List<Site_Visit__c> visits = [
            SELECT Id, Name, Status__c, Rating__c, Interest_Level__c, Next_Follow_up_After__c,
                   Visit_DateTime__c, Visitor_Mobile__c, Has_the_Guest_Visited_with_Family__c,
                   Did_the_guest_visit_the_show_flat__c, Did_the_guest_like_the_project_or_produc__c,
                   Your_Overall_Experience__c, Recommend_project_to_family_friends__c,
                   Sales_Manager_Remarks__c, Remarks__c, Comments__c,
                   Project__c, Project__r.Name,
                   Unit__c, Unit__r.Name, Unit__r.BHK_Configuration__c, Unit__r.Floor__r.Name, Unit__r.Tower__r.Name,
                   Building__c, Building__r.Name,
                   Lead__c, Lead__r.Name, Lead__r.FirstName, Lead__r.LastName, Lead__r.MobilePhone, Lead__r.Phone, Lead__r.Email,
                   Opportunity__c, Opportunity__r.Name, Opportunity__r.Account.Name, Opportunity__r.Account.Phone, Opportunity__r.Account.PersonMobilePhone, Opportunity__r.Account.PersonEmail,
                   Closing_Manager_Name__c, Closing_Manager_Name__r.Name
            FROM Site_Visit__c
            WHERE Id = :siteVisitId
            LIMIT 1
        ];

        if (visits.isEmpty()) {
            throw new AuraHandledException('Site Visit record not found for ID: ' + siteVisitId);
        }

        Site_Visit__c sv = visits[0];
        SiteVisitDetailDTO dto = new SiteVisitDetailDTO();
        dto.siteVisitId = sv.Id;
        dto.siteVisitName = sv.Name;
        dto.status = sv.Status__c;
        dto.visitDateTime = sv.Visit_DateTime__c != null ? sv.Visit_DateTime__c : System.now();

        // Customer details resolution (Lead > Opportunity > Direct on SV)
        String custName = 'Valued Visitor';
        String custMobile = String.isNotBlank(sv.Visitor_Mobile__c) ? sv.Visitor_Mobile__c : '';
        String custEmail = '';

        if (sv.Lead__c != null && sv.Lead__r != null) {
            custName = sv.Lead__r.Name;
            if (String.isBlank(custMobile)) {
                custMobile = String.isNotBlank(sv.Lead__r.MobilePhone) ? sv.Lead__r.MobilePhone : sv.Lead__r.Phone;
            }
            custEmail = sv.Lead__r.Email;
        } else if (sv.Opportunity__c != null && sv.Opportunity__r != null) {
            if (sv.Opportunity__r.Account != null) {
                custName = sv.Opportunity__r.Account.Name;
                if (String.isBlank(custMobile)) {
                    custMobile = String.isNotBlank(sv.Opportunity__r.Account.PersonMobilePhone) ? sv.Opportunity__r.Account.PersonMobilePhone : sv.Opportunity__r.Account.Phone;
                }
                custEmail = sv.Opportunity__r.Account.PersonEmail;
            } else {
                custName = sv.Opportunity__r.Name;
            }
        }

        dto.customerName = custName;
        dto.customerMobile = custMobile;
        dto.customerEmail = custEmail;

        // Project / Unit / Tower context
        dto.projectId = sv.Project__c;
        dto.projectName = sv.Project__r != null ? sv.Project__r.Name : 'Nikoo Homes';
        dto.unitId = sv.Unit__c;
        dto.unitName = sv.Unit__r != null ? sv.Unit__r.Name : '';
        dto.floorName = (sv.Unit__r != null && sv.Unit__r.Floor__r != null) ? sv.Unit__r.Floor__r.Name : '';
        dto.buildingName = sv.Building__r != null ? sv.Building__r.Name : ((sv.Unit__r != null && sv.Unit__r.Tower__r != null) ? sv.Unit__r.Tower__r.Name : '');
        dto.configuration = (sv.Unit__r != null && String.isNotBlank(sv.Unit__r.BHK_Configuration__c)) ? sv.Unit__r.BHK_Configuration__c : 'Luxury Residence';

        // Feedback values
        dto.rating = String.isNotBlank(sv.Rating__c) ? sv.Rating__c : 'Hot';
        dto.interestLevel = String.isNotBlank(sv.Interest_Level__c) ? sv.Interest_Level__c : 'High';
        dto.interestPercent = mapInterestLevelToPercent(dto.interestLevel);
        dto.overallExperience = String.isNotBlank(sv.Your_Overall_Experience__c) ? sv.Your_Overall_Experience__c : 'Superior';
        dto.likedProduct = String.isNotBlank(sv.Did_the_guest_like_the_project_or_produc__c) ? sv.Did_the_guest_like_the_project_or_produc__c : 'Product';
        dto.visitedShowFlat = String.isNotBlank(sv.Did_the_guest_visit_the_show_flat__c) ? sv.Did_the_guest_visit_the_show_flat__c : 'Yes';
        dto.visitedWithFamily = String.isNotBlank(sv.Has_the_Guest_Visited_with_Family__c) ? sv.Has_the_Guest_Visited_with_Family__c : 'Yes';
        dto.recommendFriends = String.isNotBlank(sv.Recommend_project_to_family_friends__c) ? sv.Recommend_project_to_family_friends__c : 'Yes';
        dto.nextFollowUp = String.isNotBlank(sv.Next_Follow_up_After__c) ? sv.Next_Follow_up_After__c : 'Week';

        dto.customerComments = sv.Comments__c;
        dto.executiveRemarks = sv.Remarks__c;
        dto.salesManagerRemarks = sv.Sales_Manager_Remarks__c;
        dto.quickTags = sv.Remarks__c;

        dto.closingManagerId = sv.Closing_Manager_Name__c != null ? sv.Closing_Manager_Name__c : UserInfo.getUserId();
        dto.closingManagerName = sv.Closing_Manager_Name__r != null ? sv.Closing_Manager_Name__r.Name : UserInfo.getName();

        // Active sales team members for assignment
        dto.closingManagers = new List<UserOption>();
        for (User u : [
            SELECT Id, Name, Title
            FROM User
            WHERE IsActive = true AND UserType = 'Standard'
            ORDER BY Name ASC
            LIMIT 50
        ]) {
            UserOption opt = new UserOption();
            opt.id = u.Id;
            opt.name = u.Name;
            opt.title = String.isNotBlank(u.Title) ? u.Title : 'Sales Executive';
            dto.closingManagers.add(opt);
        }

        return dto;
    }

    /**
     * @description Atomically saves all feedback and deal assessment onto the Site Visit and linked records.
     */
    @AuraEnabled
    public static SaveResult saveSiteVisitFeedback(FeedbackSaveRequest req) {
        if (req == null || req.siteVisitId == null) {
            throw new AuraHandledException('Save request or Site Visit ID cannot be null');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Site_Visit__c sv = [
                SELECT Id, Name, Status__c, Lead__c, Opportunity__c, Project__c, Project__r.Name,
                       Building__c, Unit__c, Closing_Manager_Name__c, Comments__c, Remarks__c
                FROM Site_Visit__c
                WHERE Id = :req.siteVisitId
                LIMIT 1
            ];

            // 1. Update Site Visit record
            sv.Status__c = 'Completed'; // Default target: mark visit completed
            if (String.isNotBlank(req.rating)) {
                sv.Rating__c = req.rating;
            }

            // Map interest percent to picklist value if provided
            if (req.interestPercent != null) {
                sv.Interest_Level__c = mapPercentToInterestLevel(req.interestPercent);
            } else if (String.isNotBlank(req.interestLevel)) {
                sv.Interest_Level__c = req.interestLevel;
            }

            if (String.isNotBlank(req.overallExperience)) {
                sv.Your_Overall_Experience__c = req.overallExperience;
            }
            if (String.isNotBlank(req.likedProduct)) {
                sv.Did_the_guest_like_the_project_or_produc__c = req.likedProduct;
            }
            if (String.isNotBlank(req.visitedShowFlat)) {
                sv.Did_the_guest_visit_the_show_flat__c = req.visitedShowFlat;
            }
            if (String.isNotBlank(req.visitedWithFamily)) {
                sv.Has_the_Guest_Visited_with_Family__c = req.visitedWithFamily;
            }
            if (String.isNotBlank(req.recommendFriends)) {
                sv.Recommend_project_to_family_friends__c = req.recommendFriends;
            }
            if (String.isNotBlank(req.nextFollowUp)) {
                sv.Next_Follow_up_After__c = req.nextFollowUp;
            }
            if (req.closingManagerId != null) {
                sv.Closing_Manager_Name__c = req.closingManagerId;
            }

            // Combine comments & tags cleanly
            String formattedComments = '';
            if (String.isNotBlank(req.customerComments)) {
                formattedComments = req.customerComments.trim();
            }
            if (String.isNotBlank(req.quickTags)) {
                String tagPrefix = '[Key Insights: ' + req.quickTags.trim() + ']';
                formattedComments = String.isNotBlank(formattedComments)
                    ? tagPrefix + '\n' + formattedComments
                    : tagPrefix;
            }
            if (String.isNotBlank(formattedComments)) {
                sv.Comments__c = formattedComments;
            }

            if (String.isNotBlank(req.quickTags)) {
                sv.Remarks__c = req.quickTags.length() > 255 ? req.quickTags.substring(0, 255) : req.quickTags;
            } else if (String.isNotBlank(req.executiveRemarks)) {
                sv.Remarks__c = req.executiveRemarks.length() > 255 ? req.executiveRemarks.substring(0, 255) : req.executiveRemarks;
            }

            // Ensure full Unit -> Floor -> Tower -> Property hierarchy is populated
            if (sv.Unit__c != null && (sv.Building__c == null || sv.Project__c == null)) {
                List<Unit__c> uList = [
                    SELECT Id, Property__c, Tower__c, Floor__r.Tower__c, Floor__r.Tower__r.Property__c
                    FROM Unit__c
                    WHERE Id = :sv.Unit__c
                    LIMIT 1
                ];
                if (!uList.isEmpty()) {
                    Unit__c u = uList[0];
                    if (sv.Building__c == null) {
                        sv.Building__c = (u.Tower__c != null) ? u.Tower__c : u.Floor__r.Tower__c;
                    }
                    if (sv.Project__c == null) {
                        sv.Project__c = (u.Property__c != null) ? u.Property__c : u.Floor__r.Tower__r.Property__c;
                    }
                }
            }

            if (String.isNotBlank(req.salesManagerRemarks)) {
                sv.Sales_Manager_Remarks__c = req.salesManagerRemarks.length() > 255 ? req.salesManagerRemarks.substring(0, 255) : req.salesManagerRemarks;
            }

            update sv;

            // 2. Propagate key intelligence to Lead if linked
            if (sv.Lead__c != null) {
                List<Lead> leads = [SELECT Id, Status, Rating, Projects__c, ProjectL__c, Has_Site_Visit__c, IsConverted FROM Lead WHERE Id = :sv.Lead__c LIMIT 1];
                if (!leads.isEmpty()) {
                    Lead ld = leads[0];
                    ld.Has_Site_Visit__c = true;
                    if (!ld.IsConverted && ld.Status != 'Dropped' && ld.Status != 'Archive') {
                        ld.Status = 'Site Visit';
                    }
                    if (String.isNotBlank(req.rating) && (req.rating == 'Hot' || req.rating == 'Warm' || req.rating == 'Cold')) {
                        ld.Rating = req.rating;
                    }
                    if (sv.Project__c != null) {
                        if (ld.ProjectL__c == null) {
                            ld.ProjectL__c = sv.Project__c;
                        }
                        if (String.isBlank(ld.Projects__c) && sv.Project__r != null && isValidProjectPicklistValue(sv.Project__r.Name)) {
                            ld.Projects__c = sv.Project__r.Name;
                        }
                    }
                    update ld;
                }
            }

            // 3. Propagate feedback to Opportunity if linked
            if (sv.Opportunity__c != null) {
                List<Opportunity> opps = [SELECT Id, Site_Visit_Feedback__c FROM Opportunity WHERE Id = :sv.Opportunity__c LIMIT 1];
                if (!opps.isEmpty()) {
                    Opportunity opp = opps[0];
                    String oppFeedback = 'Visit Completed (' + Datetime.now().format('dd-MMM-yyyy') + '): ' +
                        (String.isNotBlank(req.rating) ? 'Rating: ' + req.rating + ' | ' : '') +
                        (String.isNotBlank(req.interestLevel) ? 'Interest: ' + req.interestLevel + ' | ' : '') +
                        (String.isNotBlank(req.quickTags) ? 'Tags: ' + req.quickTags + ' | ' : '') +
                        (String.isNotBlank(req.customerComments) ? req.customerComments : '');
                    opp.Site_Visit_Feedback__c = oppFeedback.length() > 255 ? oppFeedback.substring(0, 255) : oppFeedback;
                    update opp;
                }
            }

            // 4. Auto-generate high-priority follow-up Task for Closing Manager
            try {
                Task followUpTask = new Task();
                followUpTask.Subject = 'Follow-up: Site Visit Completed - ' + sv.Name;
                followUpTask.Status = 'Not Started';
                followUpTask.Priority = (req.rating == 'Hot') ? 'High' : 'Normal';
                Integer daysToAdd = 2;
                if (req.nextFollowUp == 'Week') {
                    daysToAdd = 7;
                } else if (req.nextFollowUp == 'Fortnight' || req.nextFollowUp == 'Month') {
                    daysToAdd = 14;
                }
                followUpTask.ActivityDate = Date.today().addDays(daysToAdd);
                followUpTask.OwnerId = sv.Closing_Manager_Name__c != null ? sv.Closing_Manager_Name__c : UserInfo.getUserId();
                if (sv.Lead__c != null) {
                    followUpTask.WhoId = sv.Lead__c;
                    // In Salesforce, WhatId must be null when WhoId is a Lead
                } else if (sv.Opportunity__c != null) {
                    followUpTask.WhatId = sv.Opportunity__c;
                } else {
                    followUpTask.WhatId = sv.Id;
                }
                followUpTask.Description = 'Site Visit Feedback recorded.\nRating: ' + (String.isNotBlank(req.rating) ? req.rating : '-') +
                    '\nExperience: ' + (String.isNotBlank(req.overallExperience) ? req.overallExperience : '-') +
                    '\nKey Insights: ' + (String.isNotBlank(req.quickTags) ? req.quickTags : '-') +
                    '\nRemarks: ' + (String.isNotBlank(req.salesManagerRemarks) ? req.salesManagerRemarks : '-');
                insert followUpTask;
            } catch (Exception taskEx) {
                System.debug('Warning: Task creation failed: ' + taskEx.getMessage());
            }

            SaveResult res = new SaveResult();
            res.success = true;
            res.siteVisitId = sv.Id;
            res.updatedStatus = sv.Status__c;
            res.message = 'Feedback successfully recorded! Site visit marked as Completed.';
            return res;

        } catch (Exception ex) {
            Database.rollback(sp);
            throw new AuraHandledException('Failed to save site visit feedback: ' + ex.getMessage());
        }
    }

    private static Integer mapInterestLevelToPercent(String level) {
        if (String.isBlank(level)) return 75;
        if (level == 'High') return 85;
        if (level == 'Medium') return 60;
        if (level == 'Low') return 35;
        if (level == 'No Interest') return 10;
        return 75;
    }

    private static String mapPercentToInterestLevel(Integer pct) {
        if (pct == null) return 'High';
        if (pct <= 25) return 'No Interest';
        if (pct <= 50) return 'Low';
        if (pct <= 75) return 'Medium';
        return 'High';
    }

    private static Set<String> validProjectsPicklist;
    private static Boolean isValidProjectPicklistValue(String val) {
        if (String.isBlank(val)) return false;
        if (validProjectsPicklist == null) {
            validProjectsPicklist = new Set<String>();
            for (Schema.PicklistEntry ple : Schema.SObjectType.Lead.fields.Projects__c.getPicklistValues()) {
                if (ple.isActive()) {
                    validProjectsPicklist.add(ple.getValue());
                }
            }
        }
        return validProjectsPicklist.contains(val);
    }
}
