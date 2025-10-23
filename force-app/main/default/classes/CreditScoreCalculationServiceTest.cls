//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

@isTest
private class CreditScoreCalculationServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Customer',
            Phone = '555-1234',
            Age__c = 35,
            Custom_Field__c = 'Test Value',
            External_Customer_ID__c = 'CUST_TEST123',
            BillingStreet = '123 Test St',
            BillingCity = 'Test City',
            BillingState = 'CA',
            BillingPostalCode = '12345'
        );
        insert testAccount;
        
        // Create test billing records
        List<Billing_Record__c> billingRecords = new List<Billing_Record__c>();
        
        // On-time payment
        billingRecords.add(new Billing_Record__c(
            Customer__c = testAccount.Id,
            Billing_ID__c = 'BILL-001',
            Bill_Amount__c = 100.00,
            Bill_Due_Date__c = Date.today().addDays(-30),
            Bill_Payment_Date__c = Date.today().addDays(-30),
            External_System_ID__c = 'CUST_TEST123'
        ));
        
        // Late payment
        billingRecords.add(new Billing_Record__c(
            Customer__c = testAccount.Id,
            Billing_ID__c = 'BILL-002',
            Bill_Amount__c = 150.00,
            Bill_Due_Date__c = Date.today().addDays(-20),
            Bill_Payment_Date__c = Date.today().addDays(-18),
            External_System_ID__c = 'CUST_TEST123'
        ));
        
        // Another on-time payment
        billingRecords.add(new Billing_Record__c(
            Customer__c = testAccount.Id,
            Billing_ID__c = 'BILL-003',
            Bill_Amount__c = 200.00,
            Bill_Due_Date__c = Date.today().addDays(-10),
            Bill_Payment_Date__c = Date.today().addDays(-12),
            External_System_ID__c = 'CUST_TEST123'
        ));
        
        insert billingRecords;
    }
    
    @isTest
    static void testCalculateCreditScore_Success() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Customer' LIMIT 1];
        
        Test.startTest();
        
        // Test credit score calculation
        Credit_Score__c result = CreditScoreCalculationService.calculateCreditScore(testAccount.Id);
        
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Credit score should be calculated');
        System.assertEquals(testAccount.Id, result.Customer__c, 'Customer should match');
        System.assertEquals(300, result.Base_Score__c, 'Base score should be 300');
        System.assertEquals(true, result.Is_Current__c, 'Should be marked as current');
        System.assertNotEquals(null, result.Calculation_Date__c, 'Calculation date should be set');
        
        // Verify total score is sum of components
        Decimal expectedTotal = result.Base_Score__c + result.Internal_Fields_Score__c + 
                               result.External_Billing_Score__c + result.API_Score__c;
        System.assertEquals(expectedTotal, result.Total_Score__c, 'Total score should equal sum of components');
        
        // Verify account is updated
        Account updatedAccount = [SELECT Current_Credit_Score__c, Last_Score_Calculation__c 
                                 FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals(result.Total_Score__c, updatedAccount.Current_Credit_Score__c, 
                           'Account score should be updated');
        System.assertNotEquals(null, updatedAccount.Last_Score_Calculation__c, 
                              'Last calculation date should be set');
    }
    
    @isTest
    static void testCalculateCreditScore_InvalidAccount() {
        Test.startTest();
        
        try {
            // Test with invalid account ID
            CreditScoreCalculationService.calculateCreditScore(null);
            System.assert(false, 'Should throw exception for null account ID');
        } catch (CreditScoreCalculationService.CreditScoreException e) {
            System.assert(e.getMessage().contains('Account ID cannot be null'), 
                         'Should throw appropriate exception');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testCalculateCreditScore_NonExistentAccount() {
        // Create a fake account ID
        Id fakeAccountId = '001000000000000';
        
        Test.startTest();
        
        try {
            CreditScoreCalculationService.calculateCreditScore(fakeAccountId);
            System.assert(false, 'Should throw exception for non-existent account');
        } catch (CreditScoreCalculationService.CreditScoreException e) {
            System.assert(e.getMessage().contains('Account not found'), 
                         'Should throw appropriate exception');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testCalculateCreditScoresBulk_Success() {
        // Get test accounts
        List<Account> testAccounts = [SELECT Id FROM Account WHERE Name = 'Test Customer'];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }
        
        Test.startTest();
        
        // Test bulk calculation
        Map<Id, Credit_Score__c> results = CreditScoreCalculationService.calculateCreditScoresBulk(accountIds);
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(accountIds.size(), results.size(), 'Should calculate scores for all accounts');
        
        for (Id accountId : accountIds) {
            System.assert(results.containsKey(accountId), 'Should have result for each account');
            Credit_Score__c score = results.get(accountId);
            System.assertNotEquals(null, score, 'Score should not be null');
            System.assertEquals(accountId, score.Customer__c, 'Customer should match');
        }
    }
    
    @isTest
    static void testCalculateCreditScoresBulk_EmptySet() {
        Test.startTest();
        
        // Test with empty set
        Map<Id, Credit_Score__c> results = CreditScoreCalculationService.calculateCreditScoresBulk(new Set<Id>());
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(0, results.size(), 'Should return empty map for empty input');
    }
    
    @isTest
    static void testCalculateCreditScoresBulk_NullInput() {
        Test.startTest();
        
        // Test with null input
        Map<Id, Credit_Score__c> results = CreditScoreCalculationService.calculateCreditScoresBulk(null);
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(0, results.size(), 'Should return empty map for null input');
    }
    
    @isTest
    static void testScoreComponents_Calculation() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Customer' LIMIT 1];
        
        Test.startTest();
        
        Credit_Score__c result = CreditScoreCalculationService.calculateCreditScore(testAccount.Id);
        
        Test.stopTest();
        
        // Verify score components
        System.assertEquals(300, result.Base_Score__c, 'Base score should be 300');
        System.assert(result.Internal_Fields_Score__c >= 0, 'Internal fields score should be non-negative');
        System.assert(result.External_Billing_Score__c >= 0, 'Billing score should be non-negative');
        System.assert(result.API_Score__c >= 0, 'API score should be non-negative');
        
        // Verify score status is set
        System.assertNotEquals(null, result.Score_Status__c, 'Score status should be set');
        System.assert(new Set<String>{'Poor', 'Good', 'Excellent'}.contains(result.Score_Status__c), 
                     'Score status should be valid');
    }
    
    @isTest
    static void testMultipleScoreCalculations_CurrentFlag() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Customer' LIMIT 1];
        
        Test.startTest();
        
        // Calculate first score
        Credit_Score__c firstScore = CreditScoreCalculationService.calculateCreditScore(testAccount.Id);
        
        // Calculate second score
        Credit_Score__c secondScore = CreditScoreCalculationService.calculateCreditScore(testAccount.Id);
        
        Test.stopTest();
        
        // Verify only the latest score is current
        List<Credit_Score__c> allScores = [SELECT Id, Is_Current__c FROM Credit_Score__c 
                                          WHERE Customer__c = :testAccount.Id 
                                          ORDER BY Calculation_Date__c];
        
        System.assertEquals(2, allScores.size(), 'Should have two score records');
        System.assertEquals(false, allScores[0].Is_Current__c, 'First score should not be current');
        System.assertEquals(true, allScores[1].Is_Current__c, 'Second score should be current');
    }
    
    @isTest
    static void testScoreCalculation_WithMissingFields() {
        // Create account with missing fields
        Account incompleteAccount = new Account(
            Name = 'Incomplete Customer',
            External_Customer_ID__c = 'CUST_INCOMPLETE'
            // Missing Phone, Age__c, Custom_Field__c
        );
        insert incompleteAccount;
        
        Test.startTest();
        
        Credit_Score__c result = CreditScoreCalculationService.calculateCreditScore(incompleteAccount.Id);
        
        Test.stopTest();
        
        // Verify missing fields are tracked
        System.assertNotEquals(null, result.Missing_Fields__c, 'Missing fields should be tracked');
        System.assert(result.Internal_Fields_Score__c < 150, 'Internal fields score should be reduced');
    }
    
    @isTest
    static void testScoreCalculation_WithNoBillingHistory() {
        // Create account without billing records
        Account noBillingAccount = new Account(
            Name = 'No Billing Customer',
            Phone = '555-9999',
            Age__c = 25,
            External_Customer_ID__c = 'CUST_NOBILLING'
        );
        insert noBillingAccount;
        
        Test.startTest();
        
        Credit_Score__c result = CreditScoreCalculationService.calculateCreditScore(noBillingAccount.Id);
        
        Test.stopTest();
        
        // Verify billing score is zero
        System.assertEquals(0, result.External_Billing_Score__c, 'Billing score should be zero with no history');
    }
    
    @isTest
    static void testScoreComponentsWrapper() {
        Test.startTest();
        
        // Test ScoreComponents wrapper class
        CreditScoreCalculationService.ScoreComponents components = 
            new CreditScoreCalculationService.ScoreComponents();
        
        Test.stopTest();
        
        // Verify default values
        System.assertEquals(0, components.baseScore, 'Base score should default to 0');
        System.assertEquals(0, components.internalFieldsScore, 'Internal fields score should default to 0');
        System.assertEquals(0, components.billingScore, 'Billing score should default to 0');
        System.assertEquals(0, components.apiScore, 'API score should default to 0');
        System.assertEquals(0, components.totalScore, 'Total score should default to 0');
        System.assertNotEquals(null, components.missingFields, 'Missing fields list should be initialized');
    }
    
    @isTest
    static void testCustomException() {
        Test.startTest();
        
        // Test custom exception
        try {
            throw new CreditScoreCalculationService.CreditScoreException('Test exception message');
        } catch (CreditScoreCalculationService.CreditScoreException e) {
            System.assertEquals('Test exception message', e.getMessage(), 'Exception message should match');
        }
        
        Test.stopTest();
    }
}

//__________________________GenAI: Generated code ends here______________________________
