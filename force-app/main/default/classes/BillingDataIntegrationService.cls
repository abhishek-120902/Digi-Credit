//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public with sharing class BillingDataIntegrationService {
    
    private static final String BILLING_ENDPOINT = 'callout:Billing_System_API';
    private static final Integer TIMEOUT_SECONDS = 30;
    private static final Integer BATCH_SIZE = 200;
    
    /**
     * Get billing records for a specific account
     * @param accountId Account ID to get billing records for
     * @return List of Billing_Record__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Billing_Record__c> getBillingRecords(Id accountId) {
        try {
            return [
                SELECT Id, Customer__c, Billing_ID__c, Bill_Amount__c, 
                       Bill_Due_Date__c, Bill_Payment_Date__c, Is_Paid_On_Time__c,
                       Days_Late__c, Payment_Status__c, External_System_ID__c,
                       Last_Updated_From_External__c
                FROM Billing_Record__c 
                WHERE Customer__c = :accountId 
                AND Bill_Payment_Date__c != null
                ORDER BY Bill_Due_Date__c DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            System.debug('Error retrieving billing records for account ' + accountId + ': ' + e.getMessage());
            throw new AuraHandledException('Error retrieving billing records: ' + e.getMessage());
        }
    }
    
    /**
     * Calculate payment percentage for billing records
     * @param records List of billing records
     * @return Decimal percentage of on-time payments
     */
    public static Decimal calculatePaymentPercentage(List<Billing_Record__c> records) {
        if (records.isEmpty()) {
            return 0;
        }
        
        Integer totalPaidBills = 0;
        Integer onTimeBills = 0;
        
        for (Billing_Record__c record : records) {
            if (record.Bill_Payment_Date__c != null) {
                totalPaidBills++;
                if (record.Is_Paid_On_Time__c) {
                    onTimeBills++;
                }
            }
        }
        
        if (totalPaidBills == 0) {
            return 0;
        }
        
        return (Decimal.valueOf(onTimeBills) / totalPaidBills) * 100;
    }
    
    /**
     * Sync billing data from external system asynchronously
     * @param accountIds Set of Account IDs to sync billing data for
     */
    @future(callout=true)
    public static void syncBillingDataAsync(Set<Id> accountIds) {
        syncBillingData(accountIds);
    }
    
    /**
     * Sync billing data from external system
     * @param accountIds Set of Account IDs to sync billing data for
     */
    public static void syncBillingData(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }
        
        // Get accounts with external customer IDs
        Map<Id, Account> accountsMap = new Map<Id, Account>([
            SELECT Id, External_Customer_ID__c, Name
            FROM Account 
            WHERE Id IN :accountIds 
            AND External_Customer_ID__c != null
        ]);
        
        List<Billing_Record__c> recordsToUpsert = new List<Billing_Record__c>();
        
        for (Account acc : accountsMap.values()) {
            try {
                BillingResponse billingData = getBillingDataFromAPI(acc.External_Customer_ID__c);
                if (billingData != null && billingData.billing_records != null) {
                    recordsToUpsert.addAll(processBillingResponse(acc.Id, billingData));
                }
            } catch (Exception e) {
                System.debug('Error syncing billing data for account ' + acc.Id + ': ' + e.getMessage());
                // Continue with other accounts
            }
        }
        
        // Upsert billing records
        if (!recordsToUpsert.isEmpty()) {
            try {
                Database.upsert(recordsToUpsert, Billing_Record__c.Billing_ID__c, false);
            } catch (Exception e) {
                System.debug('Error upserting billing records: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Get billing data from external API
     * @param externalCustomerId External customer identifier
     * @return BillingResponse with billing data
     */
    private static BillingResponse getBillingDataFromAPI(String externalCustomerId) {
        if (String.isBlank(externalCustomerId)) {
            return null;
        }
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(BILLING_ENDPOINT + '/customer/' + externalCustomerId);
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + getAccessToken());
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_SECONDS * 1000);
        
        Http http = new Http();
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 200) {
            return (BillingResponse) JSON.deserialize(response.getBody(), BillingResponse.class);
        } else {
            throw new BillingIntegrationException('Billing API Error: ' + response.getStatusCode() + ' - ' + response.getBody());
        }
    }
    
    /**
     * Process billing response and convert to Salesforce records
     * @param accountId Account ID
     * @param billingData Billing response from API
     * @return List of Billing_Record__c records
     */
    private static List<Billing_Record__c> processBillingResponse(Id accountId, BillingResponse billingData) {
        List<Billing_Record__c> records = new List<Billing_Record__c>();
        
        for (BillingRecord apiRecord : billingData.billing_records) {
            Billing_Record__c sfRecord = new Billing_Record__c(
                Customer__c = accountId,
                Billing_ID__c = apiRecord.billing_id,
                Bill_Amount__c = apiRecord.amount,
                Bill_Due_Date__c = Date.valueOf(apiRecord.due_date),
                Bill_Payment_Date__c = String.isNotBlank(apiRecord.payment_date) ? 
                                      Date.valueOf(apiRecord.payment_date) : null,
                External_System_ID__c = billingData.customer_id,
                Last_Updated_From_External__c = System.now()
            );
            
            records.add(sfRecord);
        }
        
        return records;
    }
    
    /**
     * Get access token for billing API
     * @return Access token string
     */
    private static String getAccessToken() {
        // Implementation would depend on authentication method
        // For now, return placeholder - in real implementation, this would
        // handle OAuth token refresh or other authentication mechanisms
        return 'placeholder_token';
    }
    
    /**
     * Wrapper class for billing API response
     */
    public class BillingResponse {
        public String customer_id;
        public List<BillingRecord> billing_records;
        public BillingSummary summary;
    }
    
    /**
     * Wrapper class for individual billing record from API
     */
    public class BillingRecord {
        public String billing_id;
        public Decimal amount;
        public String currencyCode;
        public String due_date;
        public String payment_date;
        public String status;
        public Boolean is_on_time;
        public Integer days_late;
    }
    
    /**
     * Wrapper class for billing summary from API
     */
    public class BillingSummary {
        public Integer total_bills;
        public Integer paid_on_time;
        public Decimal on_time_percentage;
        public String last_updated;
    }
    
    /**
     * Custom exception for billing integration errors
     */
    public class BillingIntegrationException extends Exception {
        // Custom exception for billing integration specific errors
    }
}

//__________________________GenAI: Generated code ends here______________________________
