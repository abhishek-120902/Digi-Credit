/**
 * Test class for DigiCreditUserDiscoveryHandler
 */
@isTest
private class DigiCreditUserDiscoveryHandlerTest {
    
    @TestSetup
    static void setup() {
        // Create test user data
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@digicredit.com',
            Username = 'testuser@digicredit.com.test',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id,
            IsActive = true
        );
        insert testUser;
    }
    
    @isTest
    static void testDiscoverExistingUser() {
        Map<String, Object> userData = new Map<String, Object>{
            'email' => 'testuser@digicredit.com',
            'firstName' => 'Test',
            'lastName' => 'User'
        };
        
        Test.startTest();
        DigiCreditUserDiscoveryHandler.UserDiscoveryResult result = DigiCreditUserDiscoveryHandler.discoverUser(userData);
        Test.stopTest();
        
        System.assertEquals(DigiCreditUserDiscoveryHandler.STATUS_USER_FOUND, result.status);
        System.assertEquals('User found successfully', result.message);
        System.assertNotEquals(null, result.userData);
        
        Map<String, Object> returnedUserData = result.userData;
        System.assertEquals('testuser@digicredit.com', returnedUserData.get('email'));
        System.assertEquals('Test', returnedUserData.get('firstName'));
        System.assertEquals('User', returnedUserData.get('lastName'));
    }
    
    @isTest
    static void testDiscoverNonExistentUser() {
        Map<String, Object> userData = new Map<String, Object>{
            'email' => 'nonexistent@digicredit.com',
            'firstName' => 'Non',
            'lastName' => 'Existent'
        };
        
        Test.startTest();
        DigiCreditUserDiscoveryHandler.UserDiscoveryResult result = DigiCreditUserDiscoveryHandler.discoverUser(userData);
        Test.stopTest();
        
        System.assertEquals(DigiCreditUserDiscoveryHandler.STATUS_USER_NOT_FOUND, result.status);
        System.assertEquals('User not found, can proceed with registration', result.message);
    }
    
    @isTest
    static void testDiscoverWithMissingEmail() {
        Map<String, Object> userData = new Map<String, Object>{
            'firstName' => 'Test',
            'lastName' => 'User'
        };
        
        Test.startTest();
        DigiCreditUserDiscoveryHandler.UserDiscoveryResult result = DigiCreditUserDiscoveryHandler.discoverUser(userData);
        Test.stopTest();
        
        System.assertEquals(DigiCreditUserDiscoveryHandler.STATUS_INVALID_REQUEST, result.status);
        System.assertEquals('Email is required for user discovery', result.message);
    }
    
    @isTest
    static void testDiscoverWithEmptyEmail() {
        Map<String, Object> userData = new Map<String, Object>{
            'email' => '',
            'firstName' => 'Test',
            'lastName' => 'User'
        };
        
        Test.startTest();
        DigiCreditUserDiscoveryHandler.UserDiscoveryResult result = DigiCreditUserDiscoveryHandler.discoverUser(userData);
        Test.stopTest();
        
        System.assertEquals(DigiCreditUserDiscoveryHandler.STATUS_INVALID_REQUEST, result.status);
        System.assertEquals('Email is required for user discovery', result.message);
    }
    
    @isTest
    static void testDiscoverUserByEmail() {
        Test.startTest();
        DigiCreditUserDiscoveryHandler.UserDiscoveryResult result = DigiCreditUserDiscoveryHandler.discoverUserByEmail('testuser@digicredit.com');
        Test.stopTest();
        
        System.assertEquals(DigiCreditUserDiscoveryHandler.STATUS_USER_FOUND, result.status);
        System.assertEquals('User found successfully', result.message);
    }
    
    @isTest
    static void testUserExists() {
        Test.startTest();
        Boolean exists = DigiCreditUserDiscoveryHandler.userExists('testuser@digicredit.com');
        Boolean notExists = DigiCreditUserDiscoveryHandler.userExists('nonexistent@digicredit.com');
        Boolean emptyEmail = DigiCreditUserDiscoveryHandler.userExists('');
        Test.stopTest();
        
        System.assertEquals(true, exists);
        System.assertEquals(false, notExists);
        System.assertEquals(false, emptyEmail);
    }
    
    @isTest
    static void testGetUserByEmail() {
        Test.startTest();
        User foundUser = DigiCreditUserDiscoveryHandler.getUserByEmail('testuser@digicredit.com');
        User notFoundUser = DigiCreditUserDiscoveryHandler.getUserByEmail('nonexistent@digicredit.com');
        User emptyEmailUser = DigiCreditUserDiscoveryHandler.getUserByEmail('');
        Test.stopTest();
        
        System.assertNotEquals(null, foundUser);
        System.assertEquals('testuser@digicredit.com', foundUser.Email);
        System.assertEquals('Test', foundUser.FirstName);
        System.assertEquals('User', foundUser.LastName);
        
        System.assertEquals(null, notFoundUser);
        System.assertEquals(null, emptyEmailUser);
    }
    
    @isTest
    static void testHandleUserDiscoveryInterface() {
        DigiCreditUserDiscoveryHandler handler = new DigiCreditUserDiscoveryHandler();
        
        Map<String, Object> requestAttributes = new Map<String, Object>{
            'email' => 'testuser@digicredit.com',
            'firstName' => 'Test',
            'lastName' => 'User'
        };
        
        Test.startTest();
        Map<String, Object> result = handler.handleUserDiscovery(requestAttributes);
        Test.stopTest();
        
        System.assertEquals(DigiCreditUserDiscoveryHandler.STATUS_USER_FOUND, result.get('status'));
        System.assertEquals('User found successfully', result.get('message'));
        System.assertNotEquals(null, result.get('userData'));
        
        Map<String, Object> userData = (Map<String, Object>) result.get('userData');
        System.assertEquals('testuser@digicredit.com', userData.get('email'));
    }
    
    @isTest
    static void testHandleUserDiscoveryNotFound() {
        DigiCreditUserDiscoveryHandler handler = new DigiCreditUserDiscoveryHandler();
        
        Map<String, Object> requestAttributes = new Map<String, Object>{
            'email' => 'notfound@digicredit.com',
            'firstName' => 'Not',
            'lastName' => 'Found'
        };
        
        Test.startTest();
        Map<String, Object> result = handler.handleUserDiscovery(requestAttributes);
        Test.stopTest();
        
        System.assertEquals(DigiCreditUserDiscoveryHandler.STATUS_USER_NOT_FOUND, result.get('status'));
        System.assertEquals('User not found, can proceed with registration', result.get('message'));
    }
    
    @isTest
    static void testDiscoverBulkOperation() {
        // Test with multiple discovery requests
        List<DigiCreditUserDiscoveryHandler.UserDiscoveryResult> results = new List<DigiCreditUserDiscoveryHandler.UserDiscoveryResult>();
        
        Test.startTest();
        for (Integer i = 0; i < 200; i++) {
            Map<String, Object> userData = new Map<String, Object>{
                'email' => 'bulk' + i + '@digicredit.com',
                'firstName' => 'Bulk',
                'lastName' => 'User' + i
            };
            results.add(DigiCreditUserDiscoveryHandler.discoverUser(userData));
        }
        Test.stopTest();
        
        System.assertEquals(200, results.size());
        for (DigiCreditUserDiscoveryHandler.UserDiscoveryResult result : results) {
            System.assertEquals(DigiCreditUserDiscoveryHandler.STATUS_USER_NOT_FOUND, result.status);
        }
    }
}
