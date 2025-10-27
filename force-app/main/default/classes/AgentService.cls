public without sharing class AgentService {
    
    /**
     * Get cases assigned to the current agent user
     * @return List of Case records assigned to current user
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getAssignedCases() {
        try {
            Id currentUserId = UserInfo.getUserId();

            List<Case> cases = [SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, ContactId, Contact.Name,Description, Origin, Type, Reason FROM Case WHERE OwnerId = :currentUserId LIMIT 1000];
            
            return cases;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving assigned cases: ' + e.getMessage());
        }
    }
    
    /**
     * Get all customers for agent view (agents can view all customer information)
     * @param limitRecords Number of records to return
     * @return List of Account records
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAllCustomers(Integer limitRecords) {
        try {
            if (limitRecords == null || limitRecords <= 0) {
                limitRecords = 100;
            }

            List<Account> customers = [SELECT Id, Name, Email__c, Phone, Current_Credit_Score__c, Last_Score_Calculation__c, External_Customer_ID__c, Age__c, Custom_Field__c FROM Account WHERE IsPersonAccount = true ORDER BY Name LIMIT :limitRecords];
            
            return customers;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving customers: ' + e.getMessage());
        }
    }
    
    /**
     * Get customer details with related records for agent view
     * @param accountId Account ID to get details for
     * @return CustomerDetailsWrapper with all related information
     */
    @AuraEnabled
    public static CustomerDetailsWrapper getCustomerDetails(Id accountId) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            CustomerDetailsWrapper wrapper = new CustomerDetailsWrapper();
            
            // Get customer account details
            List<Account> accounts = [SELECT Id, Name, Email__c, Phone, Current_Credit_Score__c, Last_Score_Calculation__c, External_Customer_ID__c, Age__c, Custom_Field__c, BillingAddress, Owner.FirstName, Owner.LastName, Type, Industry FROM Account WHERE Id = :accountId AND IsPersonAccount = true LIMIT 1 ];
            
            if (accounts.isEmpty()) {
                throw new AuraHandledException('Customer not found');
            }
            
            wrapper.customer = accounts[0];
            
            // Get credit score history
            wrapper.creditScores = [SELECT Id, Total_Score__c, Base_Score__c, Internal_Fields_Score__c, External_Billing_Score__c, API_Score__c, Score_Status__c, Calculation_Date__c, Is_Current__c, Missing_Fields__c FROM Credit_Score__c WHERE Customer__c = :accountId ORDER BY Calculation_Date__c DESC LIMIT 10];
            
            // Get billing records
            wrapper.billingRecords = [SELECT Id, Billing_ID__c, Bill_Payment_Date__c, Bill_Due_Date__c, Is_Paid_On_Time__c, Bill_Amount__c, Payment_Status__c FROM Billing_Record__c WHERE Customer__c = :accountId ORDER BY Bill_Due_Date__c DESC LIMIT 50];
            
            // Get credit score requests
            wrapper.creditScoreRequests = [SELECT Id, Request_Channel__c, Request_Status__c, Requested_Date__c, Completed_Date__c, Credit_Score_Result__c, Credit_Score_Result__r.Total_Score__c, Processing_Notes__c FROM Credit_Score_Request__c WHERE Customer__c = :accountId ORDER BY Requested_Date__c DESC LIMIT 20];
            
            // Get cases related to this customer
            wrapper.cases = [SELECT Id, CaseNumber, Subject, Status, Priority, Owner.Name, Description, Origin, Type, Reason FROM Case WHERE AccountId = :accountId LIMIT 20];
            
            return wrapper;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving customer details: ' + e.getMessage());
        }
    }
    
    /**
     * Update case status and add notes
     * @param caseId Case ID to update
     * @param newStatus New status for the case
     * @param notes Additional notes to add
     * @return Updated Case record
     */
    @AuraEnabled
    public static Case updateCaseStatus(Id caseId, String newStatus, String notes) {
        try {
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required');
            }
            
            // Verify the case is assigned to current user
            List<Case> cases = [SELECT Id, Status, Description, OwnerId FROM Case WHERE Id = :caseId AND OwnerId = :UserInfo.getUserId() LIMIT 1];
            
            if (cases.isEmpty()) {
                throw new AuraHandledException('Case not found or not assigned to you');
            }
            
            Case caseToUpdate = cases[0];
            
            if (String.isNotBlank(newStatus)) {
                caseToUpdate.Status = newStatus;
            }
            
            if (String.isNotBlank(notes)) {
                String existingDescription = caseToUpdate.Description != null ? caseToUpdate.Description : '';
                String timestamp = DateTime.now().format('yyyy-MM-dd HH:mm:ss');
                String agentNote = '\n\n--- Agent Note (' + timestamp + ') ---\n' + notes;
                caseToUpdate.Description = existingDescription + agentNote;
            }
            
            update caseToUpdate;
            
            List<Case> updatedCase = [SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, Description, Origin, Type, Reason FROM Case WHERE Id = :caseId LIMIT 1];
            
            // Return updated case with related fields
            return updatedCase[0];
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating case: ' + e.getMessage());
        }
    }
    
    /**
     * Create a new case for a customer
     * @param accountId Customer Account ID
     * @param subject Case subject
     * @param description Case description
     * @param priority Case priority
     * @param origin Case origin
     * @return Created Case record
     */
    @AuraEnabled
    public static Case createCustomerCase(Id accountId, String subject, String description, 
                                        String priority, String origin) {
        try {
            if (accountId == null || String.isBlank(subject)) {
                throw new AuraHandledException('Account ID and Subject are required');
            }
            
            // Verify account exists
            List<Account> accounts = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
            if (accounts.isEmpty()) {
                throw new AuraHandledException('Customer account not found');
            }
            
            Case newCase = new Case(
                AccountId = accountId,
                Subject = subject,
                Description = description,
                Priority = String.isNotBlank(priority) ? priority : 'Medium',
                Origin = String.isNotBlank(origin) ? origin : 'Agent',
                Status = 'New',
                OwnerId = UserInfo.getUserId()
            );
            
            insert newCase;
            
            // Return case with related fields
            return [SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, Description, Origin, Type, Reason FROM Case WHERE Id = :newCase.Id LIMIT 1][0];
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating case: ' + e.getMessage());
        }
    }
    
    /**
     * Get agent dashboard statistics
     * @return AgentDashboardStats with key metrics
     */
    @AuraEnabled(cacheable=true)
    public static AgentDashboardStats getAgentDashboardStats() {
        try {
            Id currentUserId = UserInfo.getUserId();
            AgentDashboardStats stats = new AgentDashboardStats();
            
            // Get case statistics
            List<AggregateResult> caseStats = [SELECT Status, COUNT(Id) caseCount FROM Case WHERE OwnerId = :currentUserId GROUP BY Status];
            
            Integer totalCases = 0;
            Integer openCases = 0;
            Integer closedCases = 0;
            
            for (AggregateResult ar : caseStats) {
                String status = (String) ar.get('Status');
                Integer count = (Integer) ar.get('caseCount');
                totalCases += count;
                
                if (status == 'Closed') {
                    closedCases += count;
                } else {
                    openCases += count;
                }
            }
            
            stats.totalAssignedCases = totalCases;
            stats.openCases = openCases;
            stats.closedCases = closedCases;
            
            // Get recent activity
            Date today = Date.today();
            
            // Cases created today
            List<AggregateResult> casesCreatedTodayResult = [SELECT COUNT(Id) cnt FROM Case WHERE OwnerId = :currentUserId AND DAY_ONLY(CreatedDate) = :today];
            stats.casesCreatedToday = casesCreatedTodayResult.isEmpty() ? 0 : (Integer)casesCreatedTodayResult[0].get('cnt');
            
            // Cases closed today
            List<AggregateResult> casesClosedTodayResult = [SELECT COUNT(Id) cnt FROM Case WHERE OwnerId = :currentUserId AND Status = 'Closed' AND DAY_ONLY(LastModifiedDate) = :today];
            stats.casesClosedToday = casesClosedTodayResult.isEmpty() ? 0 : (Integer)casesClosedTodayResult[0].get('cnt');
            
            // Get credit score request statistics
            List<AggregateResult> totalCreditRequestsResult = [SELECT COUNT(Id) cnt FROM Credit_Score_Request__c WHERE CreatedDate = THIS_MONTH];
            stats.totalCreditRequests = totalCreditRequestsResult.isEmpty() ? 0 : (Integer)totalCreditRequestsResult[0].get('cnt');
            
            List<AggregateResult> pendingCreditRequestsResult = [SELECT COUNT(Id) cnt FROM Credit_Score_Request__c WHERE Request_Status__c IN ('Submitted', 'Processing')];
            stats.pendingCreditRequests = pendingCreditRequestsResult.isEmpty() ? 0 : (Integer)pendingCreditRequestsResult[0].get('cnt');
            
            return stats;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving dashboard stats: ' + e.getMessage());
        }
    }
    
    /**
     * Search cases by various criteria
     * @param searchTerm Search term for case number, subject, or account name
     * @param status Case status filter
     * @param priority Case priority filter
     * @return List of matching Case records
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> searchCases(String searchTerm, String status, String priority) {
        try {
            String query = 'SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, Description, Origin, Type, Reason FROM Case WHERE OwnerId = :currentUserId';
            
            Map<String, Object> bindVars = new Map<String, Object>();
            bindVars.put('currentUserId', UserInfo.getUserId());
            
            if (String.isNotBlank(searchTerm)) {
                String searchPattern = '%' + searchTerm + '%';
                query += ' AND (CaseNumber LIKE :searchPattern OR Subject LIKE :searchPattern OR Account.Name LIKE :searchPattern)';
                bindVars.put('searchPattern', searchPattern);
            }
            
            if (String.isNotBlank(status)) {
                query += ' AND Status = :status';
                bindVars.put('status', status);
            }
            
            if (String.isNotBlank(priority)) {
                query += ' AND Priority = :priority';
                bindVars.put('priority', priority);
            }
            
            query += ' LIMIT 100';
            
            return Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error searching cases: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper class for customer details
     */
    public class CustomerDetailsWrapper {
        @AuraEnabled public Account customer { get; set; }
        @AuraEnabled public List<Credit_Score__c> creditScores { get; set; }
        @AuraEnabled public List<Billing_Record__c> billingRecords { get; set; }
        @AuraEnabled public List<Credit_Score_Request__c> creditScoreRequests { get; set; }
        @AuraEnabled public List<Case> cases { get; set; }
        
        public CustomerDetailsWrapper() {
            this.creditScores = new List<Credit_Score__c>();
            this.billingRecords = new List<Billing_Record__c>();
            this.creditScoreRequests = new List<Credit_Score_Request__c>();
            this.cases = new List<Case>();
        }
    }
    
    /**
     * Get recent cases for a specific customer - only cases assigned to current agent
     * @param accountId Customer Account ID
     * @param limitRecords Number of records to return
     * @return List of Case records assigned to current user for this customer
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getRecentCases(Id accountId, Integer limitRecords) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            if (limitRecords == null || limitRecords <= 0) {
                limitRecords = 5;
            }
            
            Id currentUserId = UserInfo.getUserId();

            List<Case> recentCases = [SELECT Id, CaseNumber, Subject, Status, Priority, Owner.Name, Description, Origin, Type, Reason FROM Case WHERE AccountId = :accountId AND OwnerId = :currentUserId LIMIT :limitRecords];
            
            // Only return cases assigned to the current agent for this customer
            return recentCases;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving recent cases: ' + e.getMessage());
        }
    }
    
    /**
     * Get recent credit score requests for a specific customer
     * @param accountId Customer Account ID
     * @param limitRecords Number of records to return
     * @return List of Credit Score Request records for this customer
     */
    @AuraEnabled(cacheable=true)
    public static List<Credit_Score_Request__c> getRecentCreditRequests(Id accountId, Integer limitRecords) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            if (limitRecords == null || limitRecords <= 0) {
                limitRecords = 5;
            }
            
            List<Credit_Score_Request__c> creditScoreRequests = [SELECT Id, Request_Channel__c, Request_Status__c, Requested_Date__c, Completed_Date__c, Credit_Score_Result__c, Credit_Score_Result__r.Total_Score__c, Processing_Notes__c FROM Credit_Score_Request__c WHERE Customer__c = :accountId ORDER BY Requested_Date__c DESC LIMIT :limitRecords];
            
            return creditScoreRequests;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving recent credit requests: ' + e.getMessage());
        }
    }
    
    /**
     * Get recent billing records for a specific customer
     * @param accountId Customer Account ID
     * @param limitRecords Number of records to return
     * @return List of Billing Record records for this customer
     */
    @AuraEnabled(cacheable=true)
    public static List<Billing_Record__c> getRecentBillingRecords(Id accountId, Integer limitRecords) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            if (limitRecords == null || limitRecords <= 0) {
                limitRecords = 5;
            }
            
            List<Billing_Record__c> billingRecords = [SELECT Id, Billing_ID__c, Bill_Payment_Date__c, Bill_Due_Date__c, Is_Paid_On_Time__c, Bill_Amount__c, Payment_Status__c FROM Billing_Record__c WHERE Customer__c = :accountId ORDER BY Bill_Due_Date__c DESC LIMIT :limitRecords];
            
            return billingRecords;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving recent billing records: ' + e.getMessage());
        }
    }

    /**
     * Get credit score history for a specific customer
     * @param accountId Customer Account ID
     * @param limitRecords Number of records to return
     * @return List of Credit Score records for this customer
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
            
            List<Credit_Score__c> creditScores = [SELECT Id, Total_Score__c, Score_Status__c, Calculation_Date__c, Base_Score__c, Internal_Fields_Score__c, External_Billing_Score__c, API_Score__c, Is_Current__c, Missing_Fields__c FROM Credit_Score__c WHERE Customer__c = :accountId ORDER BY Calculation_Date__c DESC LIMIT :limitRecords];

            return creditScores;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving credit score history: ' + e.getMessage());
        }
    }

    /**
     * Wrapper class for agent dashboard statistics
     */
    public class AgentDashboardStats {
        @AuraEnabled public Integer totalAssignedCases { get; set; }
        @AuraEnabled public Integer openCases { get; set; }
        @AuraEnabled public Integer closedCases { get; set; }
        @AuraEnabled public Integer casesCreatedToday { get; set; }
        @AuraEnabled public Integer casesClosedToday { get; set; }
        @AuraEnabled public Integer totalCreditRequests { get; set; }
        @AuraEnabled public Integer pendingCreditRequests { get; set; }
        
        public AgentDashboardStats() {
            this.totalAssignedCases = 0;
            this.openCases = 0;
            this.closedCases = 0;
            this.casesCreatedToday = 0;
            this.casesClosedToday = 0;
            this.totalCreditRequests = 0;
            this.pendingCreditRequests = 0;
        }
    }
}
