/**
 * User Discovery Handler for Digi-Credit application
 * Provides user discovery functionality for registration flows
 * This class can be used as a utility for user lookup operations
 */
global class DigiCreditUserDiscoveryHandler implements Auth.HeadlessUserDiscoveryHandler {
    
    /**
     * Custom result class for user discovery operations
     */
    global class UserDiscoveryResult {
        global String status;
        global String message;
        global Map<String, Object> userData;
        
        global UserDiscoveryResult(String status, String message) {
            this.status = status;
            this.message = message;
            this.userData = new Map<String, Object>();
        }
        
        global UserDiscoveryResult(String status, String message, Map<String, Object> userData) {
            this.status = status;
            this.message = message;
            this.userData = userData;
        }
    }
    
    // Status constants
    global static final String STATUS_USER_FOUND = 'USER_FOUND';
    global static final String STATUS_USER_NOT_FOUND = 'USER_NOT_FOUND';
    global static final String STATUS_INVALID_REQUEST = 'INVALID_REQUEST';
    global static final String STATUS_ERROR = 'ERROR';
    
    /**
     * Required method for Auth.HeadlessUserDiscoveryHandler interface
     * Discovers user from login hint for headless authentication flows
     * @param networkId Network ID
     * @param loginHint Login hint (usually email)
     * @param verificationAction Verification action
     * @param authProviderName Auth provider name
     * @param requestAttributes Request attributes
     * @return Auth.HeadlessUserDiscoveryResponse containing discovery results
     */
    global Auth.HeadlessUserDiscoveryResponse discoverUserFromLoginHint(Id networkId, String loginHint, Auth.VerificationAction verificationAction, String authProviderName, Map<String, String> requestAttributes) {
        try {
            System.debug('Discovering user from login hint: ' + loginHint);
            
            // Validate login hint (usually email)
            if (String.isBlank(loginHint)) {
                return new Auth.HeadlessUserDiscoveryResponse(
                    'INVALID_REQUEST',
                    'Login hint is required for user discovery'
                );
            }
            
            // Check if user exists with the login hint (email)
            List<User> existingUsers = [
                SELECT Id, Email, FirstName, LastName, IsActive, ContactId, Username
                FROM User 
                WHERE Email = :loginHint 
                AND IsActive = true
                LIMIT 1
            ];
            
            if (!existingUsers.isEmpty()) {
                User existingUser = existingUsers[0];
                
                System.debug('User found for login hint: ' + loginHint);
                return new Auth.HeadlessUserDiscoveryResponse(
                    'USER_FOUND',
                    existingUser.Id
                );
            } else {
                System.debug('User not found for login hint: ' + loginHint);
                return new Auth.HeadlessUserDiscoveryResponse(
                    'USER_NOT_FOUND',
                    'User not found, can proceed with registration'
                );
            }
            
        } catch (Exception e) {
            System.debug('Error in discoverUserFromLoginHint: ' + e.getMessage());
            return new Auth.HeadlessUserDiscoveryResponse(
                'ERROR',
                'An error occurred during user discovery: ' + e.getMessage()
            );
        }
    }
    
    /**
     * Discovers user based on provided user data
     * @param userData Map containing user information for discovery
     * @return UserDiscoveryResult containing discovery results
     */
    global static UserDiscoveryResult discoverUser(Map<String, Object> userData) {
        try {
            // Extract user information from the provided data
            String email = (String) userData.get('email');
            String firstName = (String) userData.get('firstName');
            String lastName = (String) userData.get('lastName');
            
            // Validate required fields
            if (String.isBlank(email)) {
                return new UserDiscoveryResult(
                    STATUS_INVALID_REQUEST,
                    'Email is required for user discovery'
                );
            }
            
            // Check if user already exists
            List<User> existingUsers = [
                SELECT Id, Email, FirstName, LastName, IsActive, ContactId
                FROM User 
                WHERE Email = :email 
                AND IsActive = true
                LIMIT 1
            ];
            
            if (!existingUsers.isEmpty()) {
                User existingUser = existingUsers[0];
                
                // User found - return existing user information
                Map<String, Object> userInfo = new Map<String, Object>{
                    'userId' => existingUser.Id,
                    'email' => existingUser.Email,
                    'firstName' => existingUser.FirstName,
                    'lastName' => existingUser.LastName,
                    'contactId' => existingUser.ContactId
                };
                
                System.debug('User found for email: ' + email);
                return new UserDiscoveryResult(
                    STATUS_USER_FOUND,
                    'User found successfully',
                    userInfo
                );
            } else {
                // User not found - can proceed with registration
                System.debug('User not found for email: ' + email + ', can proceed with registration');
                return new UserDiscoveryResult(
                    STATUS_USER_NOT_FOUND,
                    'User not found, can proceed with registration'
                );
            }
            
        } catch (Exception e) {
            // Handle any unexpected errors
            System.debug('Error in user discovery: ' + e.getMessage());
            return new UserDiscoveryResult(
                STATUS_ERROR,
                'An error occurred during user discovery: ' + e.getMessage()
            );
        }
    }
    
    /**
     * Discovers user by email address
     * @param email Email address to search for
     * @return UserDiscoveryResult containing discovery results
     */
    global static UserDiscoveryResult discoverUserByEmail(String email) {
        Map<String, Object> userData = new Map<String, Object>{
            'email' => email
        };
        return discoverUser(userData);
    }
    
    /**
     * Checks if a user exists with the given email
     * @param email Email address to check
     * @return Boolean indicating if user exists
     */
    global static Boolean userExists(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        
        List<User> existingUsers = [
            SELECT Id 
            FROM User 
            WHERE Email = :email 
            AND IsActive = true
            LIMIT 1
        ];
        
        return !existingUsers.isEmpty();
    }
    
    /**
     * Gets user information by email
     * @param email Email address to search for
     * @return User record if found, null otherwise
     */
    global static User getUserByEmail(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        
        List<User> users = [
            SELECT Id, Email, FirstName, LastName, IsActive, ContactId, Username
            FROM User 
            WHERE Email = :email 
            AND IsActive = true
            LIMIT 1
        ];
        
        return users.isEmpty() ? null : users[0];
    }
}
