//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public class PermissionSetAssignmentQueueable implements Queueable {
    
    private Set<Id> userIds;
    private String permissionSetName;
    
    public PermissionSetAssignmentQueueable(Set<Id> userIds, String permissionSetName) {
        this.userIds = userIds;
        this.permissionSetName = permissionSetName;
    }
    
    public void execute(QueueableContext context) {
        try {
            // Get the permission set
            List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet 
                                                 WHERE Name = :permissionSetName LIMIT 1];
            
            if (permissionSets.isEmpty()) {
                System.debug('Permission Set not found: ' + permissionSetName);
                return;
            }
            
            Id permissionSetId = permissionSets[0].Id;
            
            // Check which users don't already have this permission set assigned
            Set<Id> existingAssignments = new Set<Id>();
            for (PermissionSetAssignment psa : [SELECT AssigneeId FROM PermissionSetAssignment 
                                               WHERE PermissionSetId = :permissionSetId 
                                               AND AssigneeId IN :userIds]) {
                existingAssignments.add(psa.AssigneeId);
            }
            
            // Create permission set assignments for users who don't have it
            List<PermissionSetAssignment> assignmentsToInsert = new List<PermissionSetAssignment>();
            
            for (Id userId : userIds) {
                if (!existingAssignments.contains(userId)) {
                    assignmentsToInsert.add(new PermissionSetAssignment(
                        AssigneeId = userId,
                        PermissionSetId = permissionSetId
                    ));
                }
            }
            
            if (!assignmentsToInsert.isEmpty()) {
                insert assignmentsToInsert;
                System.debug('Successfully assigned permission set ' + permissionSetName + 
                           ' to ' + assignmentsToInsert.size() + ' users');
            } else {
                System.debug('No new permission set assignments needed');
            }
            
        } catch (Exception e) {
            System.debug('Error assigning permission set: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________
