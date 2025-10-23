//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public class AccountTriggerHandler extends TriggerHandler {
    
    private List<Account> newAccounts;
    private List<Account> oldAccounts;
    private Map<Id, Account> newAccountMap;
    private Map<Id, Account> oldAccountMap;
    
    // Credit score relevant fields
    private static final Set<String> CREDIT_SCORE_FIELDS = new Set<String>{
        'Age__c', 'Phone', 'Custom_Field__c', 'External_Customer_ID__c'
    };
    
    public AccountTriggerHandler() {
        this.newAccounts = (List<Account>) Trigger.new;
        this.oldAccounts = (List<Account>) Trigger.old;
        this.newAccountMap = (Map<Id, Account>) Trigger.newMap;
        this.oldAccountMap = (Map<Id, Account>) Trigger.oldMap;
    }
    
    public override void afterInsert() {
        System.debug('AccountTriggerHandler.afterInsert: Processing ' + newAccounts.size() + ' accounts');
        handleCreditScoreCalculation(newAccounts, null, 'Account Insert');
    }
    
    public override void afterUpdate() {
        System.debug('AccountTriggerHandler.afterUpdate: Processing ' + newAccounts.size() + ' accounts');
        
        List<Account> accountsToProcess = getAccountsWithRelevantChanges();
        if (!accountsToProcess.isEmpty()) {
            System.debug('Found ' + accountsToProcess.size() + ' accounts with credit score relevant changes');
            handleCreditScoreCalculation(accountsToProcess, oldAccountMap, 'Account Update');
        } else {
            System.debug('No accounts found with credit score relevant changes');
        }
    }
    
    /**
     * Get accounts that have changes to credit score relevant fields
     * @return List of accounts that need credit score recalculation
     */
    private List<Account> getAccountsWithRelevantChanges() {
        List<Account> accountsToProcess = new List<Account>();
        
        for (Account newAccount : newAccounts) {
            Account oldAccount = oldAccountMap.get(newAccount.Id);
            
            // Check if any credit score relevant field has changed
            Boolean hasRelevantChange = false;
            for (String fieldName : CREDIT_SCORE_FIELDS) {
                try {
                    Object newValue = newAccount.get(fieldName);
                    Object oldValue = oldAccount.get(fieldName);
                    
                    if (newValue != oldValue) {
                        hasRelevantChange = true;
                        System.debug('Field ' + fieldName + ' changed for account ' + newAccount.Id + 
                                   ' from "' + oldValue + '" to "' + newValue + '"');
                        break;
                    }
                } catch (Exception e) {
                    System.debug('Error checking field ' + fieldName + ' for account ' + newAccount.Id + ': ' + e.getMessage());
                    // Continue checking other fields
                }
            }
            
            if (hasRelevantChange) {
                accountsToProcess.add(newAccount);
            }
        }
        
        return accountsToProcess;
    }
    
    /**
     * Handle credit score calculation for accounts
     * @param accounts List of accounts to process
     * @param oldMap Map of old account values (null for insert)
     * @param source Source of the trigger (for logging)
     */
    private void handleCreditScoreCalculation(List<Account> accounts, Map<Id, Account> oldMap, String source) {
        try {
            Set<Id> accountIds = new Set<Id>();
            
            for (Account acc : accounts) {
                // Only process accounts that have External_Customer_ID__c
                if (String.isNotBlank(acc.External_Customer_ID__c)) {
                    accountIds.add(acc.Id);
                } else {
                    System.debug('Skipping account ' + acc.Id + ' - no External_Customer_ID__c');
                }
            }
            
            if (!accountIds.isEmpty()) {
                System.debug('Queuing credit score calculation for ' + accountIds.size() + ' accounts');
                
                // Use queueable for async processing to avoid governor limits
                System.enqueueJob(new CreditScoreCalculationQueueable(accountIds, source));
            } else {
                System.debug('No accounts qualified for credit score calculation');
            }
            
        } catch (Exception e) {
            System.debug('Error in handleCreditScoreCalculation: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Don't fail the trigger - log error and continue
            logTriggerError('AccountTriggerHandler', source, e);
        }
    }
    
    /**
     * Log trigger errors for monitoring
     * @param handlerName Name of the trigger handler
     * @param source Source of the operation
     * @param e Exception that occurred
     */
    private void logTriggerError(String handlerName, String source, Exception e) {
        try {
            System.debug('=== ACCOUNT TRIGGER ERROR ===');
            System.debug('Handler: ' + handlerName);
            System.debug('Source: ' + source);
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Account Count: ' + (newAccounts != null ? newAccounts.size() : 0));
            System.debug('=============================');
            
        } catch (Exception logException) {
            System.debug('Error logging failed: ' + logException.getMessage());
        }
    }
    
    /**
     * Check if account trigger is enabled via custom setting
     * @return Boolean indicating if trigger should run
     */
    private Boolean isTriggerEnabled() {
        try {
            // Check custom setting or custom metadata for trigger control
            // For now, return true - you can implement custom setting logic here
            return true;
        } catch (Exception e) {
            System.debug('Error checking trigger enabled status: ' + e.getMessage());
            return true; // Default to enabled
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________
