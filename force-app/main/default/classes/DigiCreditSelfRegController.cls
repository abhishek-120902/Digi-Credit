public with sharing class DigiCreditSelfRegController {
    
    public String firstName { get; set; }
    public String lastName { get; set; }
    public String email { get; set; }
    public String password { get; set; }
    public String confirmPassword { get; set; }
    public String communityNickname { get; set; }
    
    public DigiCreditSelfRegController() {
        // Initialize properties
    }
    
    public PageReference registerUser() {
        // Check if user is already logged in
        if (UserInfo.getUserType() != 'Guest') {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                'You are already logged in. Please log out before creating a new account.'));
            return null;
        }
        
        // Validate required fields
        if (!validateInput()) {
            return null;
        }
        
        // Validate site configuration for Person Account registration
        String configValidationResult = validateSiteConfiguration();
        if (String.isNotBlank(configValidationResult)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, configValidationResult));
            return null;
        }
        
        // Check if user already exists
        List<User> existingUsers = [SELECT Id FROM User WHERE Email = :email LIMIT 1];
        if (!existingUsers.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                'A user with this email address already exists.'));
            return null;
        }
        
        try {
            // Create Person Account first
            Account personAccount = createPersonAccount();
            if (personAccount == null || personAccount.PersonContactId == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Failed to create account. Please contact support.'));
                return null;
            }
            
            // Create user
            User newUser = createUser(personAccount.PersonContactId);
            
            // Create the user using Site.createExternalUser
            String userId = Site.createExternalUser(newUser, null, password);
            
            if (String.isNotBlank(userId)) {
                // Assign permission set in a future method
                assignPermissionSetAsync(userId);
                
                // Redirect to login page with success message
                String loginUrl = Site.getBaseUrl() + '/login';
                PageReference loginPage = new PageReference(loginUrl);
                loginPage.getParameters().put('message', 'Registration successful. Please log in.');
                loginPage.setRedirect(true);
                return loginPage;
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Registration failed. Please try again.'));
                return null;
            }
            
        } catch (Site.ExternalUserCreateException ex) {
            List<String> errors = ex.getDisplayMessages();
            for (String error : errors) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, error));
            }
            System.debug('Registration error: ' + ex.getMessage());
            return null;
        } catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                'An unexpected error occurred. Please try again.'));
            System.debug('Registration exception: ' + ex.getMessage());
            return null;
        }
    }
    
    private Boolean validateInput() {
        Boolean isValid = true;
        
        if (String.isBlank(firstName)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'First Name is required.'));
            isValid = false;
        }
        
        if (String.isBlank(lastName)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Last Name is required.'));
            isValid = false;
        }
        
        if (String.isBlank(email)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Email is required.'));
            isValid = false;
        } else if (!isValidEmail(email)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please enter a valid email address.'));
            isValid = false;
        }
        
        if (String.isBlank(password)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Password is required.'));
            isValid = false;
        } else if (password.length() < 8) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Password must be at least 8 characters long.'));
            isValid = false;
        }
        
        if (String.isBlank(confirmPassword)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Confirm Password is required.'));
            isValid = false;
        } else if (password != confirmPassword) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Passwords do not match.'));
            isValid = false;
        }
        
        if (String.isBlank(communityNickname)) {
            communityNickname = firstName + lastName;
        }
        
        return isValid;
    }
    
    private Boolean isValidEmail(String emailAddress) {
        String emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        Pattern emailPattern = Pattern.compile(emailRegex);
        return emailPattern.matcher(emailAddress).matches();
    }
    
    /**
     * Validates site configuration for Person Account registration
     * @return Error message if configuration is invalid, null if valid
     */
    private String validateSiteConfiguration() {
        try {
            // Check if Person Accounts are enabled in the org
            if (!Schema.sObjectType.Account.fields.getMap().containsKey('IsPersonAccount')) {
                return 'Person Accounts are not enabled in this organization. Please contact your administrator to enable Person Accounts.';
            }
            
            // Check if there are any Person Account record types available
            Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
            
            // If no Person Account record type is found, provide detailed guidance
            if (personAccountRecordTypeId == null) {
                String errorMessage = 'Person Account configuration is incomplete. ';
                errorMessage += 'Please contact your administrator to: ';
                errorMessage += '1) Create a Person Account record type, OR ';
                errorMessage += '2) Set a default Person Account record type in the site\'s public access settings (Setup > Digital Experiences > All Sites > [Site Name] > Administration > Public Access Settings).';
                
                return errorMessage;
            }
            
            // Check if the current site allows self-registration
            if (!Site.isRegistrationEnabled()) {
                return 'Self-registration is not enabled for this site. Please contact your administrator.';
            }
            
            // Validate that required profiles exist for community users
            Id profileId = getDigiCreditProfileId();
            if (profileId == null) {
                return 'No suitable community profile found. Please contact your administrator to configure community user profiles.';
            }
            
            return null; // Configuration is valid
            
        } catch (Exception ex) {
            System.debug('Error validating site configuration: ' + ex.getMessage());
            return 'Unable to validate site configuration. Please contact your administrator.';
        }
    }
    
    private Account createPersonAccount() {
        try {
            // Check if Person Account already exists
            List<Account> existingAccounts = [SELECT Id, PersonContactId FROM Account 
                                            WHERE PersonEmail = :email 
                                            AND IsPersonAccount = true LIMIT 1];
            if (!existingAccounts.isEmpty()) {
                return existingAccounts[0];
            }
            
            Account personAccount = new Account();
            personAccount.FirstName = firstName;
            personAccount.LastName = lastName;
            personAccount.PersonEmail = email;
            
            // Enhanced Person Account Record Type assignment with multiple fallback strategies
            Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
            if (personAccountRecordTypeId != null) {
                personAccount.RecordTypeId = personAccountRecordTypeId;
                System.debug('Setting Person Account Record Type ID: ' + personAccountRecordTypeId);
            } else {
                // Try the default Account record type as fallback
                Id defaultRecordTypeId = getDefaultAccountRecordType();
                if (defaultRecordTypeId != null) {
                    personAccount.RecordTypeId = defaultRecordTypeId;
                    System.debug('Using default Account Record Type ID: ' + defaultRecordTypeId);
                } else {
                    // Last resort: Try hardcoded ID but validate it first
                    String hardcodedPersonAccountRTId = '012gL000002YGTQA2';
                    List<RecordType> validateRT = [SELECT Id FROM RecordType WHERE Id = :hardcodedPersonAccountRTId AND IsActive = true LIMIT 1];
                    if (!validateRT.isEmpty()) {
                        personAccount.RecordTypeId = hardcodedPersonAccountRTId;
                        System.debug('Using validated hardcoded Person Account Record Type ID: ' + hardcodedPersonAccountRTId);
                    } else {
                        // Don't set RecordTypeId - let Salesforce use org default
                        System.debug('No valid record type found. Letting Salesforce use org default.');
                    }
                }
            }
            
            insert personAccount;
            
            // Retrieve with PersonContactId
            Account insertedAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :personAccount.Id LIMIT 1];
            return insertedAccount;
            
        } catch (Exception ex) {
            System.debug('Error creating Person Account: ' + ex.getMessage());
            System.debug('Exception Type: ' + ex.getTypeName());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            
            // Provide specific error message for record type issues
            if (ex.getMessage().contains('record type') || ex.getMessage().contains('RecordType') || ex instanceof CustomException) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Person Account configuration error: ' + ex.getMessage()));
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Failed to create account. Error: ' + ex.getMessage()));
            }
            return null;
        }
    }
    
    /**
     * Gets the default Account Record Type ID as a fallback
     * @return Id of default Account record type or null if not found
     */
    private Id getDefaultAccountRecordType() {
        try {
            // Get all active Account record types
            List<RecordType> accountRTs = [SELECT Id, Name, DeveloperName, IsPersonType FROM RecordType 
                                         WHERE SObjectType = 'Account' 
                                         AND IsActive = true
                                         ORDER BY IsPersonType DESC, Name
                                         LIMIT 10];
            
            if (!accountRTs.isEmpty()) {
                // Prefer Person Account record types first
                for (RecordType rt : accountRTs) {
                    if (rt.IsPersonType == true) {
                        System.debug('Using Person Account Record Type as default: ' + rt.Name + ' (ID: ' + rt.Id + ')');
                        return rt.Id;
                    }
                }
                
                // If no Person Account record type, use the first available
                System.debug('Using first available Account Record Type: ' + accountRTs[0].Name + ' (ID: ' + accountRTs[0].Id + ')');
                return accountRTs[0].Id;
            }
            
            System.debug(LoggingLevel.WARN, 'No Account record types found in the org.');
            return null;
            
        } catch (Exception ex) {
            System.debug('Error querying default Account record types: ' + ex.getMessage());
            return null;
        }
    }

    /**
     * Gets the Person Account Record Type ID with comprehensive fallback logic
     * @return Id of Person Account record type or null if not found
     */
    private Id getPersonAccountRecordTypeId() {
        try {
            // Try multiple possible record type names and developer names
            List<RecordType> personAccountRTs = [SELECT Id, Name, DeveloperName FROM RecordType 
                                               WHERE SObjectType = 'Account' 
                                               AND IsPersonType = true
                                               AND IsActive = true
                                               ORDER BY Name
                                               LIMIT 10];
            
            if (!personAccountRTs.isEmpty()) {
                // First, try to find exact matches for common Person Account record type names
                for (RecordType rt : personAccountRTs) {
                    if (rt.DeveloperName == 'PersonAccount' || 
                        rt.DeveloperName == 'Person_Account' ||
                        rt.Name == 'Person Account' ||
                        rt.Name == 'PersonAccount') {
                        System.debug('Found Person Account Record Type: ' + rt.Name + ' (ID: ' + rt.Id + ')');
                        return rt.Id;
                    }
                }
                
                // If no exact match, return the first active person account record type
                System.debug('Using first available Person Account Record Type: ' + personAccountRTs[0].Name + ' (ID: ' + personAccountRTs[0].Id + ')');
                return personAccountRTs[0].Id;
            }
            
            // Fallback: Try without IsPersonType filter (for orgs where this field might not be available)
            List<RecordType> fallbackRTs = [SELECT Id, Name, DeveloperName FROM RecordType 
                                          WHERE SObjectType = 'Account' 
                                          AND (DeveloperName LIKE '%Person%' OR Name LIKE '%Person%')
                                          AND IsActive = true
                                          LIMIT 5];
            
            if (!fallbackRTs.isEmpty()) {
                System.debug('Using fallback Person Account Record Type: ' + fallbackRTs[0].Name + ' (ID: ' + fallbackRTs[0].Id + ')');
                return fallbackRTs[0].Id;
            }
            
            System.debug(LoggingLevel.WARN, 'No Person Account record type found in the org.');
            return null;
            
        } catch (Exception ex) {
            System.debug('Error querying Person Account record types: ' + ex.getMessage());
            return null;
        }
    }
    
    private User createUser(Id contactId) {
        User newUser = new User();
        newUser.FirstName = firstName;
        newUser.LastName = lastName;
        newUser.Email = email;
        newUser.Username = generateUniqueUsername(email);
        newUser.Alias = generateAlias(firstName, lastName);
        newUser.CommunityNickname = generateUniqueCommunityNickname(communityNickname);
        newUser.TimeZoneSidKey = 'America/New_York';
        newUser.LocaleSidKey = 'en_US';
        newUser.EmailEncodingKey = 'UTF-8';
        newUser.LanguageLocaleKey = 'en_US';
        newUser.IsActive = true;
        newUser.ContactId = contactId;
        
        // Set profile
        Id profileId = getDigiCreditProfileId();
        if (profileId != null) {
            newUser.ProfileId = profileId;
        }
        
        return newUser;
    }
    
    private String generateUniqueUsername(String emailAddress) {
        String baseUsername = emailAddress + '.digicredit';
        
        List<User> existingUsers = [SELECT Id FROM User WHERE Username = :baseUsername LIMIT 1];
        if (existingUsers.isEmpty()) {
            return baseUsername;
        }
        
        String timestamp = String.valueOf(System.currentTimeMillis());
        return emailAddress + '.' + timestamp.substring(timestamp.length() - 6) + '.digicredit';
    }
    
    private String generateAlias(String fName, String lName) {
        String alias = '';
        
        if (String.isNotBlank(fName)) {
            alias += fName.substring(0, 1).toUpperCase();
        }
        if (String.isNotBlank(lName)) {
            String lastNamePart = lName.length() >= 4 ? lName.substring(0, 4) : lName;
            alias += lastNamePart.substring(0, 1).toUpperCase();
            if (lastNamePart.length() > 1) {
                alias += lastNamePart.substring(1).toLowerCase();
            }
        }
        
        if (String.isBlank(alias)) {
            alias = 'User';
        }
        
        return alias.length() > 8 ? alias.substring(0, 8) : alias;
    }
    
    private String generateUniqueCommunityNickname(String nickname) {
        String baseNickname = nickname;
        
        List<User> existingUsers = [SELECT Id FROM User WHERE CommunityNickname = :baseNickname LIMIT 1];
        if (existingUsers.isEmpty()) {
            return baseNickname;
        }
        
        Integer counter = 1;
        String uniqueNickname = baseNickname + counter;
        
        while (counter < 100) {
            List<User> users = [SELECT Id FROM User WHERE CommunityNickname = :uniqueNickname LIMIT 1];
            if (users.isEmpty()) {
                return uniqueNickname;
            }
            counter++;
            uniqueNickname = baseNickname + counter;
        }
        
        return baseNickname + String.valueOf(System.currentTimeMillis()).substring(8);
    }
    
    private Id getDigiCreditProfileId() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Digi-Credit Customer Profile' LIMIT 1];
        if (!profiles.isEmpty()) {
            return profiles[0].Id;
        }
        
        List<Profile> fallbackProfiles = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
        if (!fallbackProfiles.isEmpty()) {
            return fallbackProfiles[0].Id;
        }
        
        List<Profile> communityProfiles = [SELECT Id FROM Profile WHERE Name LIKE '%Community%' LIMIT 1];
        if (!communityProfiles.isEmpty()) {
            return communityProfiles[0].Id;
        }
        
        return null;
    }
    
    @future
    private static void assignPermissionSetAsync(String userId) {
        try {
            // Try to assign the Credit System Customer permission set
            List<PermissionSet> permSets = [SELECT Id FROM PermissionSet 
                                          WHERE Name = 'Credit_System_Customer' LIMIT 1];
            if (!permSets.isEmpty()) {
                // Check if assignment already exists
                List<PermissionSetAssignment> existingAssignments = [SELECT Id FROM PermissionSetAssignment 
                                                                   WHERE AssigneeId = :userId 
                                                                   AND PermissionSetId = :permSets[0].Id LIMIT 1];
                if (existingAssignments.isEmpty()) {
                    PermissionSetAssignment psa = new PermissionSetAssignment();
                    psa.AssigneeId = userId;
                    psa.PermissionSetId = permSets[0].Id;
                    insert psa;
                    System.debug('Successfully assigned Credit_System_Customer permission set to user: ' + userId);
                } else {
                    System.debug('Permission set already assigned to user: ' + userId);
                }
            } else {
                System.debug('Credit_System_Customer permission set not found');
            }
        } catch (Exception ex) {
            System.debug('Error assigning permission set: ' + ex.getMessage());
        }
    }
    
    public PageReference goToLogin() {
        String loginUrl = Site.getBaseUrl() + '/login';
        PageReference loginPage = new PageReference(loginUrl);
        loginPage.setRedirect(true);
        return loginPage;
    }
    
    /**
     * Custom exception class for Person Account registration errors
     */
    public class CustomException extends Exception {}
}
