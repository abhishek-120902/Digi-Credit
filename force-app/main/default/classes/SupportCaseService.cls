public class SupportCaseService {
    
    /**
     * Get case history for a specific account
     * @param accountId Account ID to get cases for
     * @return List of Case records
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getCaseHistory(Id accountId) {
        try {
            if (accountId == null) {
                throw new SupportCaseException('Account ID is required');
            }
            
            return [SELECT Id, CaseNumber, Subject, Description, Status, Priority, CreatedDate, ClosedDate, CreatedBy.Name, Owner.Name, Type, Reason, Origin FROM Case WHERE AccountId = :accountId ORDER BY CreatedDate DESC LIMIT 100];
            
        } catch (Exception e) {
            System.debug('Error in getCaseHistory: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving case history: ' + e.getMessage());
        }
    }
    
    /**
     * Create a new support case
     * @param accountId Account ID for the case
     * @param subject Case subject
     * @param description Case description
     * @param priority Case priority
     * @return Created Case ID
     */
    @AuraEnabled
    public static Id createSupportCase(Id accountId, String subject, String description, String priority) {
        try {
            if (accountId == null) {
                throw new SupportCaseException('Account ID is required');
            }
            
            if (String.isBlank(subject)) {
                throw new SupportCaseException('Subject is required');
            }
            
            if (String.isBlank(description)) {
                throw new SupportCaseException('Description is required');
            }
            
            // Get contact for the account (for person accounts)
            Contact customerContact = getContactForAccount(accountId);
            
            Case newCase = new Case(
                AccountId = accountId,
                ContactId = customerContact?.Id,
                Subject = subject.trim(),
                Description = description.trim(),
                Priority = String.isNotBlank(priority) ? priority : 'Medium',
                Status = 'New',
                Origin = 'Community',
                Type = 'Question'
            );
            
            insert newCase;
            
            System.debug('Created new case: ' + newCase.Id + ' for account: ' + accountId);
            
            return newCase.Id;
            
        } catch (Exception e) {
            System.debug('Error in createSupportCase: ' + e.getMessage());
            throw new AuraHandledException('Error creating support case: ' + e.getMessage());
        }
    }
    
    /**
     * Update case status
     * @param caseId Case ID to update
     * @param newStatus New status value
     * @return Success message
     */
    @AuraEnabled
    public static String updateCaseStatus(Id caseId, String newStatus) {
        try {
            if (caseId == null) {
                throw new SupportCaseException('Case ID is required');
            }
            
            if (String.isBlank(newStatus)) {
                throw new SupportCaseException('Status is required');
            }
            
            Case caseToUpdate = new Case(
                Id = caseId,
                Status = newStatus
            );
            
            update caseToUpdate;
            
            return 'Case status updated successfully';
            
        } catch (Exception e) {
            System.debug('Error in updateCaseStatus: ' + e.getMessage());
            throw new AuraHandledException('Error updating case status: ' + e.getMessage());
        }
    }
    
    /**
     * Get case details by ID
     * @param caseId Case ID
     * @return Case record with details
     */
    @AuraEnabled(cacheable=true)
    public static Case getCaseDetails(Id caseId) {
        try {
            if (caseId == null) {
                throw new SupportCaseException('Case ID is required');
            }
            
            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Description, Status, Priority, 
                       CreatedDate, ClosedDate, CreatedBy.Name, Owner.Name,
                       Type, Reason, Origin, AccountId, Account.Name,
                       ContactId, Contact.Name, Contact.Email
                FROM Case 
                WHERE Id = :caseId 
                LIMIT 1
            ];
            
            if (cases.isEmpty()) {
                throw new SupportCaseException('Case not found');
            }
            
            return cases[0];
            
        } catch (Exception e) {
            System.debug('Error in getCaseDetails: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving case details: ' + e.getMessage());
        }
    }
    
    /**
     * Get cases by status for an account
     * @param accountId Account ID
     * @param status Case status to filter by
     * @return List of Case records
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getCasesByStatus(Id accountId, String status) {
        try {
            if (accountId == null) {
                throw new SupportCaseException('Account ID is required');
            }
            
            String query = 'SELECT Id, CaseNumber, Subject, Description, Status, Priority, ' +
                          'CreatedDate, ClosedDate, CreatedBy.Name, Owner.Name, Type, Reason, Origin ' +
                          'FROM Case WHERE AccountId = :accountId';
            
            if (String.isNotBlank(status)) {
                query += ' AND Status = :status';
            }
            
            query += ' ORDER BY CreatedDate DESC LIMIT 100';
            
            return Database.query(query);
            
        } catch (Exception e) {
            System.debug('Error in getCasesByStatus: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving cases by status: ' + e.getMessage());
        }
    }
    
    /**
     * Add comment to case
     * @param caseId Case ID
     * @param commentBody Comment text
     * @return Success message
     */
    @AuraEnabled
    public static String addCaseComment(Id caseId, String commentBody) {
        try {
            if (caseId == null) {
                throw new SupportCaseException('Case ID is required');
            }
            
            if (String.isBlank(commentBody)) {
                throw new SupportCaseException('Comment body is required');
            }
            
            CaseComment comment = new CaseComment(
                ParentId = caseId,
                CommentBody = commentBody.trim(),
                IsPublished = true
            );
            
            insert comment;
            
            return 'Comment added successfully';
            
        } catch (Exception e) {
            System.debug('Error in addCaseComment: ' + e.getMessage());
            throw new AuraHandledException('Error adding case comment: ' + e.getMessage());
        }
    }
    
    /**
     * Get case comments
     * @param caseId Case ID
     * @return List of CaseComment records
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseComment> getCaseComments(Id caseId) {
        try {
            if (caseId == null) {
                throw new SupportCaseException('Case ID is required');
            }
            
            return [
                SELECT Id, CommentBody, CreatedDate, CreatedBy.Name, IsPublished
                FROM CaseComment 
                WHERE ParentId = :caseId 
                AND IsPublished = true
                ORDER BY CreatedDate ASC
            ];
            
        } catch (Exception e) {
            System.debug('Error in getCaseComments: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving case comments: ' + e.getMessage());
        }
    }
    
    /**
     * Get case statistics for an account
     * @param accountId Account ID
     * @return Map of case statistics
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getCaseStatistics(Id accountId) {
        try {
            if (accountId == null) {
                throw new SupportCaseException('Account ID is required');
            }
            
            Map<String, Integer> stats = new Map<String, Integer>();
            
            // Get total cases
            Integer totalCases = [SELECT COUNT() FROM Case WHERE AccountId = :accountId];
            stats.put('total', totalCases);
            
            // Get open cases
            Integer openCases = [SELECT COUNT() FROM Case WHERE AccountId = :accountId AND IsClosed = false];
            stats.put('open', openCases);
            
            // Get closed cases
            Integer closedCases = [SELECT COUNT() FROM Case WHERE AccountId = :accountId AND IsClosed = true];
            stats.put('closed', closedCases);
            
            // Get cases by priority
            List<AggregateResult> priorityResults = [
                SELECT Priority, COUNT(Id) caseCount 
                FROM Case 
                WHERE AccountId = :accountId 
                GROUP BY Priority
            ];
            
            for (AggregateResult result : priorityResults) {
                String priority = (String) result.get('Priority');
                Integer count = (Integer) result.get('caseCount');
                stats.put(priority?.toLowerCase(), count);
            }
            
            return stats;
            
        } catch (Exception e) {
            System.debug('Error in getCaseStatistics: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving case statistics: ' + e.getMessage());
        }
    }
    
    /**
     * Get contact for account (handles person accounts)
     * @param accountId Account ID
     * @return Contact record or null
     */
    private static Contact getContactForAccount(Id accountId) {
        try {
            // Check if it's a person account
            List<Account> accounts = [
                SELECT Id, IsPersonAccount, PersonContactId 
                FROM Account 
                WHERE Id = :accountId 
                LIMIT 1
            ];
            
            if (accounts.isEmpty()) {
                return null;
            }
            
            Account account = accounts[0];
            
            if (account.IsPersonAccount && account.PersonContactId != null) {
                // Person account - return the person contact
                return [SELECT Id FROM Contact WHERE Id = :account.PersonContactId LIMIT 1];
            } else {
                // Business account - find primary contact
                List<Contact> contacts = [
                    SELECT Id 
                    FROM Contact 
                    WHERE AccountId = :accountId 
                    ORDER BY CreatedDate ASC 
                    LIMIT 1
                ];
                
                return contacts.isEmpty() ? null : contacts[0];
            }
            
        } catch (Exception e) {
            System.debug('Error getting contact for account: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Validate case access for current user
     * @param caseId Case ID
     * @return True if user has access
     */
    public static Boolean validateCaseAccess(Id caseId) {
        try {
            if (caseId == null) {
                return false;
            }
            
            // Check if user can access the case
            List<Case> accessibleCases = [
                SELECT Id 
                FROM Case 
                WHERE Id = :caseId 
                LIMIT 1
            ];
            
            return !accessibleCases.isEmpty();
            
        } catch (Exception e) {
            System.debug('Error validating case access: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Custom exception for support case operations
     */
    public class SupportCaseException extends Exception {
        // Custom exception class
    }
}