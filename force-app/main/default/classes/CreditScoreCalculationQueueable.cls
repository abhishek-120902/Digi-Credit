//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public class CreditScoreCalculationQueueable implements Queueable {
    
    private Set<Id> accountIds;
    private String source;
    
    public CreditScoreCalculationQueueable(Set<Id> accountIds) {
        this.accountIds = accountIds;
        this.source = 'Trigger';
    }
    
    public CreditScoreCalculationQueueable(Set<Id> accountIds, String source) {
        this.accountIds = accountIds;
        this.source = source;
    }
    
    public void execute(QueueableContext context) {
        try {
            if (accountIds == null || accountIds.isEmpty()) {
                System.debug('CreditScoreCalculationQueueable: No account IDs provided');
                return;
            }
            
            System.debug('CreditScoreCalculationQueueable: Processing ' + accountIds.size() + ' accounts from ' + source);
            
            // Calculate credit scores for all accounts
            Map<Id, Credit_Score__c> results = CreditScoreCalculationService.calculateCreditScoresBulk(accountIds);
            
            // Log successful calculations
            System.debug('Credit scores calculated for ' + results.size() + ' accounts');
            
            // Update any related Credit Score Requests
            updateRelatedRequests(accountIds, results);
            
            // Send notifications if needed
            sendNotifications(results);
            
        } catch (Exception e) {
            System.debug('Error in CreditScoreCalculationQueueable: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Log error for monitoring
            logError(e);
        }
    }
    
    /**
     * Update related Credit Score Requests with calculation results
     * @param accountIds Set of Account IDs that were processed
     * @param results Map of Account ID to Credit Score records
     */
    private void updateRelatedRequests(Set<Id> accountIds, Map<Id, Credit_Score__c> results) {
        try {
            List<Credit_Score_Request__c> requestsToUpdate = [
                SELECT Id, Customer__c, Request_Status__c, Credit_Score_Result__c
                FROM Credit_Score_Request__c
                WHERE Customer__c IN :accountIds
                AND Request_Status__c IN ('Submitted', 'Processing')
                WITH SECURITY_ENFORCED
                ORDER BY Requested_Date__c DESC
            ];
            
            List<Credit_Score_Request__c> updatedRequests = new List<Credit_Score_Request__c>();
            
            for (Credit_Score_Request__c request : requestsToUpdate) {
                if (results.containsKey(request.Customer__c)) {
                    Credit_Score__c creditScore = results.get(request.Customer__c);
                    
                    request.Request_Status__c = 'Completed';
                    request.Completed_Date__c = System.now();
                    request.Credit_Score_Result__c = creditScore.Id;
                    
                    updatedRequests.add(request);
                }
            }
            
            if (!updatedRequests.isEmpty()) {
                update updatedRequests;
                System.debug('Updated ' + updatedRequests.size() + ' Credit Score Requests');
            }
            
        } catch (Exception e) {
            System.debug('Error updating Credit Score Requests: ' + e.getMessage());
            // Don't fail the main process for request update errors
        }
    }
    
    /**
     * Send notifications for completed calculations
     * @param results Map of Account ID to Credit Score records
     */
    private void sendNotifications(Map<Id, Credit_Score__c> results) {
        try {
            // Get accounts that need notifications
            List<Account> accountsForNotification = [
                SELECT Id, Name, Email__c, Current_Credit_Score__c
                FROM Account
                WHERE Id IN :results.keySet()
                AND Email__c != null
                WITH SECURITY_ENFORCED
                LIMIT 50
            ];
            
            if (!accountsForNotification.isEmpty()) {
                // Queue email notifications
                System.enqueueJob(new CreditScoreEmailNotificationQueueable(accountsForNotification, results));
            }
            
        } catch (Exception e) {
            System.debug('Error queuing notifications: ' + e.getMessage());
            // Don't fail the main process for notification errors
        }
    }
    
    /**
     * Log error for monitoring and debugging
     * @param e Exception that occurred
     */
    private void logError(Exception e) {
        try {
            // Create error log record (if you have a custom logging object)
            // For now, just use System.debug
            System.debug('=== CREDIT SCORE CALCULATION ERROR ===');
            System.debug('Source: ' + source);
            System.debug('Account IDs: ' + String.join(new List<Id>(accountIds), ', '));
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('========================================');
            
        } catch (Exception logException) {
            System.debug('Error logging failed: ' + logException.getMessage());
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________
