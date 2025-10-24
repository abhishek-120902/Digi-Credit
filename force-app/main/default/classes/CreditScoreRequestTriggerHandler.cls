public class CreditScoreRequestTriggerHandler extends TriggerHandler {
    
    private List<Credit_Score_Request__c> newRequests;
    private List<Credit_Score_Request__c> oldRequests;
    private Map<Id, Credit_Score_Request__c> newRequestsMap;
    private Map<Id, Credit_Score_Request__c> oldRequestsMap;
    
    public CreditScoreRequestTriggerHandler() {
        this.newRequests = (List<Credit_Score_Request__c>) Trigger.new;
        this.oldRequests = (List<Credit_Score_Request__c>) Trigger.old;
        this.newRequestsMap = (Map<Id, Credit_Score_Request__c>) Trigger.newMap;
        this.oldRequestsMap = (Map<Id, Credit_Score_Request__c>) Trigger.oldMap;
    }
    
    /**
     * After Insert - Process new credit score requests
     */
    protected override void afterInsert() {
        handleNewCreditScoreRequests(this.newRequests);
    }
    
    /**
     * After Update - Handle status changes and reprocessing
     */
    protected override void afterUpdate() {
        handleCreditScoreRequestUpdates(this.newRequests, this.oldRequestsMap);
    }
    
    /**
     * Handle new credit score requests by initiating calculation
     * @param newRequests List of newly inserted Credit_Score_Request__c records
     */
    private void handleNewCreditScoreRequests(List<Credit_Score_Request__c> newRequests) {
        if (newRequests == null || newRequests.isEmpty()) {
            return;
        }
        
        Set<Id> accountIds = new Set<Id>();
        List<Credit_Score_Request__c> requestsToUpdate = new List<Credit_Score_Request__c>();
        
        // Collect account IDs and prepare requests for status update
        for (Credit_Score_Request__c request : newRequests) {
            if (request.Customer__c != null && request.Request_Status__c == 'Submitted') {
                accountIds.add(request.Customer__c);
                
                // Update request status to Processing
                Credit_Score_Request__c requestUpdate = new Credit_Score_Request__c(
                    Id = request.Id,
                    Request_Status__c = 'Processing',
                    Processing_Notes__c = 'Credit score calculation initiated.'
                );
                requestsToUpdate.add(requestUpdate);
            }
        }
        
        if (!accountIds.isEmpty()) {
            try {
                // Update request status to Processing
                if (!requestsToUpdate.isEmpty()) {
                    update requestsToUpdate;
                }
                
                // Process credit score calculations asynchronously
                if (accountIds.size() <= 10) {
                    // For small batches, process immediately
                    processCreditScoreCalculations(accountIds, newRequests);
                } else {
                    // For larger batches, use queueable job
                    System.enqueueJob(new CreditScoreCalculationQueueable(accountIds));
                }
                
            } catch (Exception e) {
                System.debug('Error processing credit score requests: ' + e.getMessage());
                
                // Update failed requests
                List<Credit_Score_Request__c> failedRequests = new List<Credit_Score_Request__c>();
                for (Credit_Score_Request__c request : newRequests) {
                    if (accountIds.contains(request.Customer__c)) {
                        failedRequests.add(new Credit_Score_Request__c(
                            Id = request.Id,
                            Request_Status__c = 'Failed',
                            Processing_Notes__c = 'Error during processing: ' + e.getMessage(),
                            Completed_Date__c = System.now()
                        ));
                    }
                }
                
                if (!failedRequests.isEmpty()) {
                    update failedRequests;
                }
            }
        }
    }
    
    /**
     * Handle credit score request updates
     * @param updatedRequests List of updated Credit_Score_Request__c records
     * @param oldRequestsMap Map of old Credit_Score_Request__c records
     */
    private void handleCreditScoreRequestUpdates(List<Credit_Score_Request__c> updatedRequests, 
                                                Map<Id, Credit_Score_Request__c> oldRequestsMap) {
        if (updatedRequests == null || updatedRequests.isEmpty() || oldRequestsMap == null) {
            return;
        }
        
        Set<Id> accountIdsToReprocess = new Set<Id>();
        
        // Check for requests that need reprocessing
        for (Credit_Score_Request__c request : updatedRequests) {
            Credit_Score_Request__c oldRequest = oldRequestsMap.get(request.Id);
            
            // Reprocess if status changed from Failed to Submitted or Processing
            if (oldRequest != null && 
                oldRequest.Request_Status__c == 'Failed' && 
                (request.Request_Status__c == 'Submitted' || request.Request_Status__c == 'Processing')) {
                
                if (request.Customer__c != null) {
                    accountIdsToReprocess.add(request.Customer__c);
                }
            }
        }
        
        // Process reprocessing requests
        if (!accountIdsToReprocess.isEmpty()) {
            try {
                if (accountIdsToReprocess.size() <= 5) {
                    // Process small batches immediately
                    processCreditScoreCalculations(accountIdsToReprocess, updatedRequests);
                } else {
                    // Use queueable for larger batches
                    System.enqueueJob(new CreditScoreCalculationQueueable(accountIdsToReprocess));
                }
            } catch (Exception e) {
                System.debug('Error reprocessing credit score requests: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Process credit score calculations and update requests
     * @param accountIds Set of Account IDs to calculate scores for
     * @param relatedRequests List of related Credit_Score_Request__c records
     */
    private void processCreditScoreCalculations(Set<Id> accountIds, List<Credit_Score_Request__c> relatedRequests) {
        Map<Id, Credit_Score_Request__c> requestsByAccountId = new Map<Id, Credit_Score_Request__c>();
        
        // Map requests by account ID for easy lookup
        for (Credit_Score_Request__c request : relatedRequests) {
            if (accountIds.contains(request.Customer__c)) {
                requestsByAccountId.put(request.Customer__c, request);
            }
        }
        
        List<Credit_Score_Request__c> requestsToUpdate = new List<Credit_Score_Request__c>();
        
        // Process each account
        for (Id accountId : accountIds) {
            try {
                // Calculate credit score
                Credit_Score__c creditScore = CreditScoreCalculationService.calculateCreditScore(accountId);
                
                // Update related request with success
                Credit_Score_Request__c relatedRequest = requestsByAccountId.get(accountId);
                if (relatedRequest != null) {
                    requestsToUpdate.add(new Credit_Score_Request__c(
                        Id = relatedRequest.Id,
                        Request_Status__c = 'Completed',
                        Credit_Score_Result__c = creditScore.Id,
                        Completed_Date__c = System.now(),
                        Processing_Notes__c = 'Credit score calculated successfully. Score: ' + (creditScore.Total_Score__c != null ? String.valueOf(creditScore.Total_Score__c) : '')
                    ));
                }
                
                // Send email notification if configured
                sendCreditScoreNotification(accountId, creditScore);
                
            } catch (Exception e) {
                System.debug('Error calculating credit score for account ' + accountId + ': ' + e.getMessage());
                
                // Update related request with failure
                Credit_Score_Request__c relatedRequest = requestsByAccountId.get(accountId);
                if (relatedRequest != null) {
                    requestsToUpdate.add(new Credit_Score_Request__c(
                        Id = relatedRequest.Id,
                        Request_Status__c = 'Failed',
                        Completed_Date__c = System.now(),
                        Processing_Notes__c = 'Error calculating credit score: ' + e.getMessage()
                    ));
                }
            }
        }
        
        // Update all requests
        if (!requestsToUpdate.isEmpty()) {
            try {
                update requestsToUpdate;
            } catch (Exception e) {
                System.debug('Error updating credit score requests: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Send email notification for completed credit score
     * @param accountId Account ID
     * @param creditScore Calculated Credit_Score__c record
     */
    private void sendCreditScoreNotification(Id accountId, Credit_Score__c creditScore) {
        try {
            // Get account data for email notification
            List<Account> accounts = [
                SELECT Id, Name, Email__c 
                FROM Account 
                WHERE Id = :accountId 
                LIMIT 1
            ];
            
            if (!accounts.isEmpty()) {
                Map<Id, Credit_Score__c> creditScoreMap = new Map<Id, Credit_Score__c>();
                creditScoreMap.put(accountId, creditScore);
                
                // Enqueue email notification job with proper parameters
                System.enqueueJob(new CreditScoreEmailNotificationQueueable(accounts, creditScoreMap));
            }
        } catch (Exception e) {
            System.debug('Error enqueueing email notification: ' + e.getMessage());
            // Don't fail the main process if email fails
        }
    }
    
    /**
     * Validate credit score request data
     * @param requests List of Credit_Score_Request__c records to validate
     * @return List of validation errors
     */
    private List<String> validateCreditScoreRequests(List<Credit_Score_Request__c> requests) {
        List<String> errors = new List<String>();
        
        if (requests == null || requests.isEmpty()) {
            return errors;
        }
        
        Set<Id> accountIds = new Set<Id>();
        for (Credit_Score_Request__c request : requests) {
            if (request.Customer__c == null) {
                errors.add('Customer is required for credit score request');
            } else {
                accountIds.add(request.Customer__c);
            }
        }
        
        // Validate that accounts exist
        if (!accountIds.isEmpty()) {
            Map<Id, Account> existingAccounts = new Map<Id, Account>([
                SELECT Id FROM Account WHERE Id IN :accountIds
            ]);
            
            for (Id accountId : accountIds) {
                if (!existingAccounts.containsKey(accountId)) {
                    errors.add('Invalid customer account: ' + accountId);
                }
            }
        }
        
        return errors;
    }
    
    /**
     * Check for duplicate requests within a time window
     * @param newRequests List of new Credit_Score_Request__c records
     * @return Set of account IDs that have recent requests
     */
    private Set<Id> checkForDuplicateRequests(List<Credit_Score_Request__c> newRequests) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> duplicateAccountIds = new Set<Id>();
        
        for (Credit_Score_Request__c request : newRequests) {
            if (request.Customer__c != null) {
                accountIds.add(request.Customer__c);
            }
        }
        
        if (!accountIds.isEmpty()) {
            // Check for requests in the last 24 hours
            DateTime yesterday = System.now().addDays(-1);
            
            List<Credit_Score_Request__c> recentRequests = [
                SELECT Customer__c 
                FROM Credit_Score_Request__c 
                WHERE Customer__c IN :accountIds 
                AND Requested_Date__c >= :yesterday
                AND Request_Status__c IN ('Submitted', 'Processing', 'Completed')
                WITH SECURITY_ENFORCED
            ];
            
            for (Credit_Score_Request__c recentRequest : recentRequests) {
                duplicateAccountIds.add(recentRequest.Customer__c);
            }
        }
        
        return duplicateAccountIds;
    }
}
