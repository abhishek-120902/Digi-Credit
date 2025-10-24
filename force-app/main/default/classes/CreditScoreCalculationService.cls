public without sharing class CreditScoreCalculationService {
    
    // Constants for score calculation
    private static final Decimal BASE_SCORE = 300.00;
    private static final Decimal MAX_INTERNAL_POINTS = 150.00;
    private static final Decimal MAX_BILLING_POINTS = 150.00;
    private static final Integer MIN_BILLING_RECORDS_FOR_FULL_SCORE = 3;
    private static final Decimal INSUFFICIENT_BILLING_PENALTY = 0.5;
    
    /**
     * Main method to calculate credit score for a single account
     * @param accountId The Account ID to calculate score for
     * @return Credit_Score__c record with calculated score
     */
    @AuraEnabled
    public static Credit_Score__c calculateCreditScore(Id accountId) {
        try {
            // Validate input
            validateInputs(accountId);
            
            // Get customer data with all required fields
            Account customer = getCustomerData(accountId);
            
            // Calculate each score component
            ScoreComponents components = new ScoreComponents();
            components.baseScore = BASE_SCORE;
            components.internalFieldsScore = calculateInternalFieldsScore(customer);
            components.billingScore = calculateBillingScore(accountId);
            components.apiScore = getExternalAPIScore(customer.External_Customer_ID__c);
            
            // Calculate total and determine status
            components.totalScore = components.baseScore + components.internalFieldsScore + 
                                   components.billingScore + components.apiScore;
            components.scoreStatus = CreditScoreUtils.determineScoreStatus(components.totalScore);
            components.scoreColor = CreditScoreUtils.getScoreColor(components.totalScore);
            
            // Analyze missing fields for improvement suggestions
            components.missingFields = CreditScoreUtils.analyzeMissingFields(customer, 
                CreditScoreConfigurationService.getActiveInternalFields());
            
            // Generate calculation details for audit
            components.calculationDetails = CreditScoreUtils.generateCalculationDetails(components);
            
            // Create credit score record
            Credit_Score__c creditScore = createCreditScoreRecord(accountId, components);
            
            // Update account with current score
            updateAccountScore(accountId, components.totalScore);
            
            // Log successful calculation
            logCalculation(accountId, components.totalScore, true, null);
            
            return creditScore;
            
        } catch (Exception e) {
            // Log error and handle gracefully
            System.debug('Credit Score Calculation Error for Account ' + accountId + ': ' + e.getMessage());
            logCalculation(accountId, null, false, e.getMessage());
            throw new AuraHandledException('Failed to calculate credit score: ' + e.getMessage());
        }
    }
    
    /**
     * Bulk calculation method for multiple accounts
     * @param accountIds Set of Account IDs to calculate scores for
     * @return Map of Account ID to Credit_Score__c records
     */
    public static Map<Id, Credit_Score__c> calculateCreditScoresBulk(Set<Id> accountIds) {
        Map<Id, Credit_Score__c> results = new Map<Id, Credit_Score__c>();
        
        if (accountIds == null || accountIds.isEmpty()) {
            return results;
        }
        
        // Process in batches to respect governor limits
        List<Id> accountList = new List<Id>(accountIds);
        Integer batchSize = 100;
        
        for (Integer i = 0; i < accountList.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, accountList.size());
            
            for (Integer j = i; j < endIndex; j++) {
                Id accountId = accountList[j];
                try {
                    Credit_Score__c score = calculateCreditScore(accountId);
                    results.put(accountId, score);
                } catch (Exception e) {
                    System.debug('Error calculating score for account ' + accountId + ': ' + e.getMessage());
                    // Continue processing other accounts
                }
            }
        }
        
        return results;
    }
    
    /**
     * Get credit score requests for a specific account or all requests
     * @param accountId Account ID to filter by (null for all requests)
     * @return List of Credit_Score_Request__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Credit_Score_Request__c> getCreditScoreRequests(Id accountId) {
        try {
            String query = 'SELECT Id, Customer__c, Customer__r.Name, Request_Channel__c, ' +
                          'Request_Status__c, Requested_Date__c, Completed_Date__c, ' +
                          'Credit_Score_Result__c ' +
                          'FROM Credit_Score_Request__c ';
            
            if (accountId != null) {
                query += 'WHERE Customer__c = :accountId ';
            }
            
            query += 'ORDER BY Requested_Date__c DESC LIMIT 1000';
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving credit score requests: ' + e.getMessage());
        }
    }
    
        /**
     * Create a new credit score request
     * @param accountId Account ID to create request for
     * @param requestChannel Channel through which request was made
     * @return Credit_Score_Request__c record
     */
    @AuraEnabled
    public static Credit_Score_Request__c createCreditScoreRequest(Id accountId, String requestChannel, String processingNotes) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            if (String.isBlank(requestChannel)) {
                requestChannel = 'Web';
            }
            
            Credit_Score_Request__c request = new Credit_Score_Request__c(
                Customer__c = accountId,
                Request_Channel__c = requestChannel,
                Processing_Notes__c = processingNotes,
                Request_Status__c = 'Submitted',
                Requested_Date__c = System.now()
            );
            
                        insert request;
            
            // Note: Credit score calculation will be automatically triggered by CreditScoreRequestTrigger
            // No need to manually enqueue job here as the trigger handles it
            
            return request;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating credit score request: ' + e.getMessage());
        }
    }
    
    /**
     * Get credit score history for an account
     * @param accountId Account ID to get history for
     * @param limitRecords Number of records to return
     * @return List of Credit_Score__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Credit_Score__c> getCreditScoreHistory(Id accountId, Integer limitRecords) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            if (limitRecords == null || limitRecords <= 0) {
                limitRecords = 10;
            }
            
            return [
                SELECT Id, Total_Score__c, Base_Score__c, Internal_Fields_Score__c,
                       External_Billing_Score__c, API_Score__c, Score_Status__c,
                       Calculation_Date__c, Is_Current__c, Missing_Fields__c
                FROM Credit_Score__c
                WHERE Customer__c = :accountId
                ORDER BY Calculation_Date__c DESC
                LIMIT :limitRecords
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving credit score history: ' + e.getMessage());
        }
    }
    
    /**
     * Get current user's account ID (for community users)
     * @return Account ID of the current user
     */
    @AuraEnabled(cacheable=true)
    public static Id getCurrentUserAccount() {
        try {
            User currentUser = [SELECT Id, ContactId, Contact.AccountId 
                              FROM User 
                              WHERE Id = :UserInfo.getUserId() 
                              AND ContactId != null
                              LIMIT 1];
            
            if (currentUser.ContactId != null && currentUser.Contact.AccountId != null) {
                return currentUser.Contact.AccountId;
            }
            
            return null;
        } catch (Exception e) {
            System.debug('Error getting current user account: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Update Account profile information for community users
     * @param accountId Account ID to update
     * @param profileData Map containing field updates
     * @return Success message or error details
     */
    @AuraEnabled
    public static String updateAccountProfile(Id accountId, Map<String, Object> profileData) {
        try {
            // Validate input
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            if (profileData == null || profileData.isEmpty()) {
                return 'No changes to save';
            }
            
            // Get current user's account to ensure they can only update their own record
            Id currentUserAccountId = getCurrentUserAccount();
            if (currentUserAccountId == null || currentUserAccountId != accountId) {
                throw new AuraHandledException('You can only update your own profile');
            }
            
            // Retrieve the account record
            Account accountToUpdate = [SELECT Id, FirstName, LastName, PersonEmail, Phone, Age__c FROM Account WHERE Id = :accountId AND IsPersonAccount = true LIMIT 1];
            
            if (accountToUpdate == null) {
                throw new AuraHandledException('Account not found or not a Person Account');
            }
            
            // Update fields based on provided data
            Boolean hasChanges = false;
            
            if (profileData.containsKey('firstName') && profileData.get('firstName') != null) {
                String newFirstName = String.valueOf(profileData.get('firstName'));
                if (newFirstName != accountToUpdate.FirstName) {
                    accountToUpdate.FirstName = newFirstName;
                    hasChanges = true;
                }
            }
            
            if (profileData.containsKey('lastName') && profileData.get('lastName') != null) {
                String newLastName = String.valueOf(profileData.get('lastName'));
                if (newLastName != accountToUpdate.LastName) {
                    accountToUpdate.LastName = newLastName;
                    hasChanges = true;
                }
            }
            
            if (profileData.containsKey('personEmail') && profileData.get('personEmail') != null) {
                String newEmail = String.valueOf(profileData.get('personEmail'));
                if (newEmail != accountToUpdate.PersonEmail) {
                    accountToUpdate.PersonEmail = newEmail;
                    hasChanges = true;
                }
            }
            
            if (profileData.containsKey('phone') && profileData.get('phone') != null) {
                String newPhone = String.valueOf(profileData.get('phone'));
                if (newPhone != accountToUpdate.Phone) {
                    accountToUpdate.Phone = newPhone;
                    hasChanges = true;
                }
            }
            
            if (profileData.containsKey('age')) {
                Object ageValue = profileData.get('age');
                Integer newAge = null;
                if (ageValue != null && String.valueOf(ageValue).trim() != '') {
                    try {
                        newAge = Integer.valueOf(String.valueOf(ageValue));
                    } catch (Exception e) {
                        throw new AuraHandledException('Invalid age value provided');
                    }
                }
                if (newAge != accountToUpdate.Age__c) {
                    accountToUpdate.Age__c = newAge;
                    hasChanges = true;
                }
            }
            
            // Update the record if there are changes
            if (hasChanges) {
                // Use without sharing class for the update to bypass sharing rules
                AccountUpdateHelper.updateAccount(accountToUpdate);
                System.debug('Successfully updated Account: ' + accountId);
                return 'Profile updated successfully';
            } else {
                return 'No changes to save';
            }
            
        } catch (DmlException e) {
            System.debug('DML Error updating account: ' + e.getMessage());
            String errorMessage = 'Failed to update profile: ';
            if (e.getDmlMessage(0) != null) {
                errorMessage += e.getDmlMessage(0);
            } else {
                errorMessage += e.getMessage();
            }
            throw new AuraHandledException(errorMessage);
        } catch (Exception e) {
            System.debug('Error updating account profile: ' + e.getMessage());
            throw new AuraHandledException('Error updating profile: ' + e.getMessage());
        }
    }

    /**
     * Search customers by name, email, or phone
     * @param searchTerm Search term to match against
     * @return List of Account records
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> searchCustomers(String searchTerm) {
        try {
            if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
                return new List<Account>();
            }
            
            String searchPattern = '%' + searchTerm + '%';
            
            return [
                SELECT Id, Name, Email__c, Phone, Current_Credit_Score__c,
                       Last_Score_Calculation__c
                FROM Account
                WHERE (Name LIKE :searchPattern 
                       OR Email__c LIKE :searchPattern 
                       OR Phone LIKE :searchPattern)
                ORDER BY Name
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error searching customers: ' + e.getMessage());
        }
    }
    
    /**
     * Bulk recalculate credit scores for multiple accounts
     * @param accountIds List of Account IDs to recalculate
     * @return String status message
     */
    @AuraEnabled
    public static String bulkRecalculateScores(List<Id> accountIds) {
        try {
            if (accountIds == null || accountIds.isEmpty()) {
                // If no specific accounts provided, get all accounts
                List<Account> allAccounts = [SELECT Id FROM Account LIMIT 10000];
                accountIds = new List<Id>();
                for (Account acc : allAccounts) {
                    accountIds.add(acc.Id);
                }
            }
            
            if (accountIds.size() > 50) {
                throw new AuraHandledException('Maximum 50 accounts can be processed at once');
            }
            
            // Enqueue async job for bulk processing
            System.enqueueJob(new CreditScoreCalculationQueueable(new Set<Id>(accountIds)));
            
            return 'Bulk recalculation started for ' + accountIds.size() + ' accounts';
        } catch (Exception e) {
            throw new AuraHandledException('Error starting bulk recalculation: ' + e.getMessage());
        }
    }
    
    /**
     * Get system analytics for executive dashboard
     * @return Map containing system analytics data
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSystemAnalytics() {
        try {
            Map<String, Object> analytics = new Map<String, Object>();
            
            // Get counts using simple approach
            List<Account> allAccounts = [SELECT Id FROM Account];
            List<Credit_Score__c> allScores = [SELECT Id FROM Credit_Score__c];
            List<Credit_Score_Request__c> pendingRequests = [SELECT Id FROM Credit_Score_Request__c WHERE Request_Status__c = 'Pending'];
            
            Date today = Date.today();
            List<Credit_Score_Request__c> completedToday = [SELECT Id FROM Credit_Score_Request__c WHERE Request_Status__c = 'Completed' AND DAY_ONLY(Completed_Date__c) = :today];
            
            // Score distribution
            List<Account> poorScores = [SELECT Id FROM Account WHERE Current_Credit_Score__c >= 300 AND Current_Credit_Score__c < 450];
            List<Account> goodScores = [SELECT Id FROM Account WHERE Current_Credit_Score__c >= 450 AND Current_Credit_Score__c < 600];
            List<Account> excellentScores = [SELECT Id FROM Account WHERE Current_Credit_Score__c >= 600];
            
            // Average credit score
            AggregateResult avgResult = [SELECT AVG(Current_Credit_Score__c) avgScore FROM Account WHERE Current_Credit_Score__c != null][0];
            
            // Populate analytics
            analytics.put('totalCustomers', allAccounts.size());
            analytics.put('totalScoresCalculated', allScores.size());
            analytics.put('averageCreditScore', avgResult.get('avgScore') != null ? Math.round((Decimal)avgResult.get('avgScore')) : 0);
            analytics.put('pendingRequests', pendingRequests.size());
            analytics.put('completedRequestsToday', completedToday.size());
            
            // Score distribution
            Map<String, Integer> scoreDistribution = new Map<String, Integer>();
            scoreDistribution.put('poor', poorScores.size());
            scoreDistribution.put('good', goodScores.size());
            scoreDistribution.put('excellent', excellentScores.size());
            analytics.put('scoreDistribution', scoreDistribution);
            
            // System health score (simplified calculation)
            Integer totalAccounts = allAccounts.size();
            Integer excellentCount = excellentScores.size();
            Integer systemHealth = totalAccounts > 0 ? Math.round((excellentCount * 100.0) / totalAccounts) : 0;
            analytics.put('systemHealthScore', systemHealth);
            
            return analytics;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving system analytics: ' + e.getMessage());
        }
    }
    
    /**
     * Calculate score based on internal Salesforce fields
     * @param customer Account record with all required fields
     * @return Decimal score from internal fields
     */
    private static Decimal calculateInternalFieldsScore(Account customer) {
        List<Credit_Score_Configuration__mdt> configs = CreditScoreConfigurationService.getActiveInternalFields();
        
        if (configs.isEmpty()) {
            return 0;
        }
        
        Decimal pointsPerField = MAX_INTERNAL_POINTS / configs.size();
        Decimal totalScore = 0;
        
        for (Credit_Score_Configuration__mdt config : configs) {
            try {
                Object fieldValue = customer.get(config.Field_API_Name__c);
                
                if (fieldValue != null && String.valueOf(fieldValue).trim() != '') {
                    totalScore += pointsPerField;
                }
            } catch (Exception e) {
                System.debug('Error accessing field ' + config.Field_API_Name__c + ': ' + e.getMessage());
                // Continue with other fields
            }
        }
        
        return totalScore;
    }
    
    /**
     * Calculate score based on billing payment history
     * @param accountId Account ID to get billing records for
     * @return Decimal score from billing history
     */
    private static Decimal calculateBillingScore(Id accountId) {
        List<Billing_Record__c> billingRecords = BillingDataIntegrationService.getBillingRecords(accountId);
        
        if (billingRecords.isEmpty()) {
            return 0; // No billing history available
        }
        
        Integer totalPaidBills = 0;
        Integer onTimeBills = 0;
        
        for (Billing_Record__c record : billingRecords) {
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
        
        Decimal paymentPercentage = (Decimal.valueOf(onTimeBills) / totalPaidBills) * 100;
        Decimal billingScore = (paymentPercentage / 100) * MAX_BILLING_POINTS;
        
        // Apply penalty for insufficient billing history
        if (totalPaidBills < MIN_BILLING_RECORDS_FOR_FULL_SCORE) {
            billingScore = billingScore * INSUFFICIENT_BILLING_PENALTY;
        }
        
        return billingScore;
    }
    
    /**
     * Get external credit score from credit bureau API
     * @param externalCustomerId External customer identifier
     * @return Decimal score from external API
     */
    private static Decimal getExternalAPIScore(String externalCustomerId) {
        if (String.isBlank(externalCustomerId)) {
            return 0;
        }
        
        try {
            return ExternalAPICalloutService.getCreditBureauScore(externalCustomerId);
        } catch (Exception e) {
            System.debug('External API Error for customer ' + externalCustomerId + ': ' + e.getMessage());
            // Return cached score or 0 if API is unavailable
            return getCachedAPIScore(externalCustomerId);
        }
    }
    
    /**
     * Get customer data with all required fields for calculation
     * @param accountId Account ID to retrieve
     * @return Account record with required fields
     */
    private static Account getCustomerData(Id accountId) {
        List<String> fieldsToQuery = new List<String>{
            'Id', 'Name', 'Phone', 'External_Customer_ID__c', 'Age__c', 'Custom_Field__c'
        };
        
        // Add dynamic fields from configuration
        List<Credit_Score_Configuration__mdt> configs = CreditScoreConfigurationService.getActiveInternalFields();
        for (Credit_Score_Configuration__mdt config : configs) {
            if (!fieldsToQuery.contains(config.Field_API_Name__c)) {
                fieldsToQuery.add(config.Field_API_Name__c);
            }
        }
        
        String query = 'SELECT ' + String.join(fieldsToQuery, ', ') + ' FROM Account WHERE Id = :accountId LIMIT 1';
        
        List<Account> accounts = Database.query(query);
        
        if (accounts.isEmpty()) {
            throw new CreditScoreException('Account not found: ' + accountId);
        }
        
        return accounts[0];
    }
    
    /**
     * Create Credit_Score__c record with calculated components
     * @param accountId Account ID
     * @param components ScoreComponents with all calculated values
     * @return Credit_Score__c record
     */
    private static Credit_Score__c createCreditScoreRecord(Id accountId, ScoreComponents components) {
        // Mark existing scores as not current
        List<Credit_Score__c> existingScores = [
            SELECT Id, Is_Current__c 
            FROM Credit_Score__c 
            WHERE Customer__c = :accountId AND Is_Current__c = true
        ];
        
        for (Credit_Score__c existingScore : existingScores) {
            existingScore.Is_Current__c = false;
        }
        
        if (!existingScores.isEmpty()) {
            update existingScores;
        }
        
        // Create new credit score record
        Credit_Score__c creditScore = new Credit_Score__c(
            Customer__c = accountId,
            Base_Score__c = components.baseScore,
            Internal_Fields_Score__c = components.internalFieldsScore,
            External_Billing_Score__c = components.billingScore,
            API_Score__c = components.apiScore,
            Is_Current__c = true,
            Calculation_Date__c = System.now(),
            Calculation_Details__c = components.calculationDetails,
            Missing_Fields__c = String.join(components.missingFields, ', ')
        );
        
        insert creditScore;
        return creditScore;
    }
    
    /**
     * Update Account record with current credit score
     * @param accountId Account ID to update
     * @param totalScore Calculated total score
     */
    private static void updateAccountScore(Id accountId, Decimal totalScore) {

        // Verify account exists
        List<Account> accounts = [SELECT Id, Current_Credit_Score__c, Last_Score_Calculation__c FROM Account WHERE Id = :accountId LIMIT 1];
        accounts[0].Current_Credit_Score__c = totalScore;
        accounts[0].Last_Score_Calculation__c = System.now();

        update accounts;

        // Account accountToUpdate = new Account(
        //     Id = accountId,
        //     Current_Credit_Score__c = totalScore,
        //     Last_Score_Calculation__c = System.now()
        // );
        
        // update accountToUpdate;
    }
    
    /**
     * Get cached API score if external API is unavailable
     * @param externalCustomerId External customer ID
     * @return Cached score or 0
     */
    private static Decimal getCachedAPIScore(String externalCustomerId) {
        // Implementation for caching mechanism
        // For now, return 0 if API is unavailable
        return 0;
    }
    
    /**
     * Validate input parameters
     * @param accountId Account ID to validate
     */
    private static void validateInputs(Id accountId) {
        if (accountId == null) {
            throw new CreditScoreException('Account ID cannot be null');
        }
        
        // Verify account exists
        List<Account> accounts = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
        if (accounts.isEmpty()) {
            throw new CreditScoreException('Account not found: ' + accountId);
        }
    }
    
    /**
     * Log calculation results for audit purposes
     * @param accountId Account ID
     * @param score Calculated score
     * @param success Whether calculation was successful
     * @param errorMessage Error message if failed
     */
    private static void logCalculation(Id accountId, Decimal score, Boolean success, String errorMessage) {
        // Implementation for logging - could be custom object or platform events
        System.debug('Credit Score Calculation - Account: ' + accountId + 
                    ', Score: ' + score + ', Success: ' + success + 
                    ', Error: ' + errorMessage);
    }
    
    /**
     * Wrapper class to hold all score components
     */
    public class ScoreComponents {
        public Decimal baseScore { get; set; }
        public Decimal internalFieldsScore { get; set; }
        public Decimal billingScore { get; set; }
        public Decimal apiScore { get; set; }
        public Decimal totalScore { get; set; }
        public String scoreStatus { get; set; }
        public String scoreColor { get; set; }
        public List<String> missingFields { get; set; }
        public String calculationDetails { get; set; }
        
        public ScoreComponents() {
            this.baseScore = 0;
            this.internalFieldsScore = 0;
            this.billingScore = 0;
            this.apiScore = 0;
            this.totalScore = 0;
            this.missingFields = new List<String>();
        }
    }
    
    /**
     * Custom exception for credit score calculation errors
     */
    public class CreditScoreException extends Exception {
        // Custom exception class for credit score specific errors
    }
}