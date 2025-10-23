//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public class BillingRecordTriggerHandler extends TriggerHandler {
    
    private List<Billing_Record__c> newRecords;
    private List<Billing_Record__c> oldRecords;
    private Map<Id, Billing_Record__c> newRecordMap;
    private Map<Id, Billing_Record__c> oldRecordMap;
    
    // Billing fields that affect credit score calculation
    private static final Set<String> CREDIT_SCORE_FIELDS = new Set<String>{
        'Bill_Due_Date__c', 'Bill_Payment_Date__c', 'Bill_Amount__c', 'Customer__c'
    };
    
    public BillingRecordTriggerHandler() {
        this.newRecords = (List<Billing_Record__c>) Trigger.new;
        this.oldRecords = (List<Billing_Record__c>) Trigger.old;
        this.newRecordMap = (Map<Id, Billing_Record__c>) Trigger.newMap;
        this.oldRecordMap = (Map<Id, Billing_Record__c>) Trigger.oldMap;
    }
    
    public override void afterInsert() {
        System.debug('BillingRecordTriggerHandler.afterInsert: Processing ' + newRecords.size() + ' billing records');
        handleCreditScoreRecalculation(newRecords, 'Billing Insert');
    }
    
    public override void afterUpdate() {
        System.debug('BillingRecordTriggerHandler.afterUpdate: Processing ' + newRecords.size() + ' billing records');
        
        List<Billing_Record__c> recordsToProcess = getBillingRecordsWithRelevantChanges();
        if (!recordsToProcess.isEmpty()) {
            System.debug('Found ' + recordsToProcess.size() + ' billing records with credit score relevant changes');
            handleCreditScoreRecalculation(recordsToProcess, 'Billing Update');
        } else {
            System.debug('No billing records found with credit score relevant changes');
        }
    }
    
    public override void afterDelete() {
        System.debug('BillingRecordTriggerHandler.afterDelete: Processing ' + oldRecords.size() + ' billing records');
        handleCreditScoreRecalculation(oldRecords, 'Billing Delete');
    }
    
    /**
     * Get billing records that have changes to credit score relevant fields
     * @return List of billing records that need credit score recalculation
     */
    private List<Billing_Record__c> getBillingRecordsWithRelevantChanges() {
        List<Billing_Record__c> recordsToProcess = new List<Billing_Record__c>();
        
        for (Billing_Record__c newRecord : newRecords) {
            Billing_Record__c oldRecord = oldRecordMap.get(newRecord.Id);
            
            // Check if any credit score relevant field has changed
            Boolean hasRelevantChange = false;
            for (String fieldName : CREDIT_SCORE_FIELDS) {
                try {
                    Object newValue = newRecord.get(fieldName);
                    Object oldValue = oldRecord.get(fieldName);
                    
                    if (newValue != oldValue) {
                        hasRelevantChange = true;
                        System.debug('Field ' + fieldName + ' changed for billing record ' + newRecord.Id + 
                                   ' from "' + oldValue + '" to "' + newValue + '"');
                        break;
                    }
                } catch (Exception e) {
                    System.debug('Error checking field ' + fieldName + ' for billing record ' + newRecord.Id + ': ' + e.getMessage());
                    // Continue checking other fields
                }
            }
            
            if (hasRelevantChange) {
                recordsToProcess.add(newRecord);
            }
        }
        
        return recordsToProcess;
    }
    
    /**
     * Handle credit score recalculation for affected customers
     * @param records List of billing records that changed
     * @param source Source of the trigger (for logging)
     */
    private void handleCreditScoreRecalculation(List<Billing_Record__c> records, String source) {
        try {
            Set<Id> customerIds = new Set<Id>();
            
            for (Billing_Record__c record : records) {
                if (record.Customer__c != null) {
                    customerIds.add(record.Customer__c);
                } else {
                    System.debug('Billing record ' + record.Id + ' has no Customer__c value');
                }
            }
            
            if (!customerIds.isEmpty()) {
                System.debug('Queuing credit score recalculation for ' + customerIds.size() + ' customers');
                
                // Use queueable for async processing to avoid governor limits
                System.enqueueJob(new CreditScoreCalculationQueueable(customerIds, source));
            } else {
                System.debug('No customers found for credit score recalculation');
            }
            
        } catch (Exception e) {
            System.debug('Error in handleCreditScoreRecalculation: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Don't fail the trigger - log error and continue
            logTriggerError('BillingRecordTriggerHandler', source, e);
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
            System.debug('=== BILLING RECORD TRIGGER ERROR ===');
            System.debug('Handler: ' + handlerName);
            System.debug('Source: ' + source);
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Record Count: ' + (newRecords != null ? newRecords.size() : 
                                           (oldRecords != null ? oldRecords.size() : 0)));
            System.debug('====================================');
            
        } catch (Exception logException) {
            System.debug('Error logging failed: ' + logException.getMessage());
        }
    }
    
    /**
     * Check if billing record trigger is enabled via custom setting
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
