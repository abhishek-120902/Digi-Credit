//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

trigger UserTrigger on User (after insert) {
    
    if (Trigger.isAfter && Trigger.isInsert) {
        // Get community users that need permission set assignment
        Set<Id> communityUserIds = new Set<Id>();
        
        for (User newUser : Trigger.new) {
            // Check if this is a community user (has ContactId and is active)
            if (newUser.ContactId != null && newUser.IsActive) {
                // Check if it's a community profile (not internal Salesforce user)
                if (newUser.ProfileId != null) {
                    communityUserIds.add(newUser.Id);
                }
            }
        }
        
        // Assign permission set asynchronously if we have community users
        if (!communityUserIds.isEmpty()) {
            System.enqueueJob(new PermissionSetAssignmentQueueable(
                communityUserIds, 
                'Credit_System_Customer'
            ));
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________
