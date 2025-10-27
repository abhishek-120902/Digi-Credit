public without sharing class CaseUpdateService {
    
    @AuraEnabled
    public static String updateCaseRecord(Id caseId, String caseType, String origin, String description, String comments) {
        try {
            // Validate input parameters
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required');
            }
            
            // Query the existing case record
            Case caseRecord = [SELECT Id, Type, Origin, Description, Comments FROM Case WHERE Id = :caseId WITH SECURITY_ENFORCED LIMIT 1];
            
            // Update only the fields that are provided
            if (String.isNotBlank(caseType)) {
                caseRecord.Type = caseType;
            }
            
            if (String.isNotBlank(origin)) {
                caseRecord.Origin = origin;
            }
            
            // if (String.isNotBlank(comments)) {
            //     caseRecord.Comments = comments;
            // }
            
            if (String.isNotBlank(description)) {
                caseRecord.Description = description;
            }
            
            // Update the case record
            update caseRecord;
            
            return 'SUCCESS';
            
        } catch (DmlException e) {
            throw new AuraHandledException('DML Error: ' + e.getDmlMessage(0));
        } catch (QueryException e) {
            throw new AuraHandledException('Query Error: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected Error: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Case getCaseRecord(Id caseId) {
        try {
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required');
            }
            
            return [SELECT Id, CaseNumber, Subject, Description, Status, Priority, Origin, Type, Reason, 
                          CreatedDate, LastModifiedDate, ClosedDate, OwnerId, Owner.FirstName, Owner.LastName, 
                          AccountId, Account.Name, ContactId, Contact.Name, Contact.Email, Contact.Phone, Comments
                   FROM Case 
                   WHERE Id = :caseId 
                   WITH SECURITY_ENFORCED 
                   LIMIT 1];
                   
        } catch (QueryException e) {
            throw new AuraHandledException('Query Error: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected Error: ' + e.getMessage());
        }
    }
}