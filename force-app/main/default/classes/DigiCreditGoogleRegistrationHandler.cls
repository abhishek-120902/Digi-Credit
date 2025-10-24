//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

global class DigiCreditGoogleRegistrationHandler implements Auth.RegistrationHandler {
    
    global User createUser(Id portalId, Auth.UserData data) {
        System.debug('Creating user with Google data: ' + JSON.serialize(data));
        
        // Check if user already exists
        List<User> existingUsers = [SELECT Id, IsActive, ContactId FROM User WHERE Email = :data.email LIMIT 1];
        if (!existingUsers.isEmpty() && existingUsers[0].IsActive) {
            System.debug('Existing active user found: ' + existingUsers[0].Id);
            return existingUsers[0];
        }
        
        // Create Person Account first - this is critical for community users
        Account personAccount = createPersonAccount(data);
        if (personAccount == null || personAccount.PersonContactId == null) {
            throw new Auth.AuthProviderPluginException('Failed to create Person Account or Contact for user registration');
        }
        
        // Create new user
        User newUser = new User();
        newUser.FirstName = String.isNotBlank(data.firstName) ? data.firstName : extractFirstName(data.fullName);
        newUser.LastName = String.isNotBlank(data.lastName) ? data.lastName : extractLastName(data.fullName);
        newUser.Email = data.email;
        newUser.Username = generateUniqueUsername(data.email);
        newUser.Alias = generateAlias(newUser.FirstName, newUser.LastName);
        newUser.TimeZoneSidKey = 'America/New_York';
        newUser.LocaleSidKey = 'en_US';
        newUser.EmailEncodingKey = 'UTF-8';
        newUser.LanguageLocaleKey = 'en_US';
        newUser.IsActive = true;
        
        // Set community profile - this is required for portal users
        Id profileId = getDigiCreditProfileId();
        if (profileId == null) {
            throw new Auth.AuthProviderPluginException('No suitable community profile found for user registration');
        }
        newUser.ProfileId = profileId;
        
        // Link to Person Account Contact - this is mandatory for community users
        newUser.ContactId = personAccount.PersonContactId;
        
        System.debug('Creating user with ContactId: ' + newUser.ContactId + ' and ProfileId: ' + newUser.ProfileId);
        
        // Note: Permission set assignment will be done after user creation in a separate transaction
        return newUser;
    }
    
    global void updateUser(Id userId, Id portalId, Auth.UserData data) {
        System.debug('Updating user: ' + userId + ' with data: ' + JSON.serialize(data));
        
        User userToUpdate = [SELECT Id, FirstName, LastName, Email, ContactId FROM User WHERE Id = :userId];
        
        Boolean needsUpdate = false;
        
        // Update user information if missing
        if (String.isBlank(userToUpdate.FirstName) && String.isNotBlank(data.firstName)) {
            userToUpdate.FirstName = data.firstName;
            needsUpdate = true;
        }
        if (String.isBlank(userToUpdate.LastName) && String.isNotBlank(data.lastName)) {
            userToUpdate.LastName = data.lastName;
            needsUpdate = true;
        }
        
        if (needsUpdate) {
            update userToUpdate;
        }
        
        // Update associated Person Account if exists
        if (userToUpdate.ContactId != null) {
            updatePersonAccount(userToUpdate.ContactId, data);
        }
    }
    
    private Account createPersonAccount(Auth.UserData data) {
        try {
            // Check if Person Account already exists for this email
            List<Account> existingAccounts = [SELECT Id, PersonContactId FROM Account 
                                            WHERE PersonEmail = :data.email 
                                            AND IsPersonAccount = true LIMIT 1];
            if (!existingAccounts.isEmpty()) {
                System.debug('Found existing Person Account: ' + existingAccounts[0].Id);
                return existingAccounts[0];
            }
            
            Account personAccount = new Account();
            personAccount.FirstName = String.isNotBlank(data.firstName) ? data.firstName : extractFirstName(data.fullName);
            personAccount.LastName = String.isNotBlank(data.lastName) ? data.lastName : extractLastName(data.fullName);
            personAccount.PersonEmail = data.email;
            personAccount.Email__c = data.email;
            
            // Set Person Account Record Type - try multiple approaches
            List<RecordType> personAccountRT = [SELECT Id FROM RecordType 
                                              WHERE SObjectType = 'Account' 
                                              AND (DeveloperName = 'PersonAccount' OR Name = 'Person Account') 
                                              LIMIT 1];
            if (!personAccountRT.isEmpty()) {
                personAccount.RecordTypeId = personAccountRT[0].Id;
                System.debug('Using Person Account Record Type: ' + personAccountRT[0].Id);
            } else {
                // If no Person Account record type found, check if Person Accounts are enabled
                System.debug('No Person Account Record Type found - Person Accounts may not be enabled');
                throw new Auth.AuthProviderPluginException('Person Accounts are not enabled in this org. Please enable Person Accounts or use a different registration approach.');
            }
            
            // Add required fields that might be missing
            if (String.isBlank(personAccount.FirstName)) {
                personAccount.FirstName = 'Google';
            }
            if (String.isBlank(personAccount.LastName)) {
                personAccount.LastName = 'User';
            }
            
            System.debug('Inserting Person Account: ' + JSON.serialize(personAccount));
            insert personAccount;
            
            // Retrieve the account with PersonContactId - wait for trigger processing
            Account insertedAccount = [SELECT Id, PersonContactId, Name FROM Account WHERE Id = :personAccount.Id LIMIT 1];
            
            if (insertedAccount.PersonContactId == null) {
                System.debug('PersonContactId is null after insert - this indicates Person Account setup issue');
                throw new Auth.AuthProviderPluginException('Person Account was created but PersonContactId is null. Please check Person Account configuration.');
            }
            
            System.debug('Successfully created Person Account: ' + insertedAccount.Id + ' with ContactId: ' + insertedAccount.PersonContactId);
            return insertedAccount;
            
        } catch (DmlException e) {
            System.debug('DML Error creating Person Account: ' + e.getMessage());
            System.debug('DML Error details: ' + e.getDmlMessage(0));
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new Auth.AuthProviderPluginException('Failed to create Person Account: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            System.debug('General Error creating Person Account: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new Auth.AuthProviderPluginException('Failed to create Person Account: ' + e.getMessage());
        }
    }
    
    private void updatePersonAccount(Id contactId, Auth.UserData data) {
        try {
            Contact contact = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId LIMIT 1];
            Account personAccount = [SELECT Id, FirstName, LastName, PersonEmail FROM Account WHERE Id = :contact.AccountId LIMIT 1];
            
            Boolean needsUpdate = false;
            
            if (String.isBlank(personAccount.FirstName) && String.isNotBlank(data.firstName)) {
                personAccount.FirstName = data.firstName;
                needsUpdate = true;
            }
            if (String.isBlank(personAccount.LastName) && String.isNotBlank(data.lastName)) {
                personAccount.LastName = data.lastName;
                needsUpdate = true;
            }
            
            if (needsUpdate) {
                update personAccount;
            }
        } catch (Exception e) {
            System.debug('Error updating Person Account: ' + e.getMessage());
        }
    }
    
    private String generateUniqueUsername(String email) {
        String baseUsername = email + '.digicredit';
        
        // Check if username already exists
        List<User> existingUsers = [SELECT Id FROM User WHERE Username = :baseUsername LIMIT 1];
        if (existingUsers.isEmpty()) {
            return baseUsername;
        }
        
        // Generate unique username with timestamp
        String timestamp = String.valueOf(System.currentTimeMillis());
        return email + '.' + timestamp.substring(timestamp.length() - 6) + '.digicredit';
    }
    
    private String generateAlias(String firstName, String lastName) {
        String alias = '';
        
        if (String.isNotBlank(firstName)) {
            alias += firstName.substring(0, 1).toUpperCase();
        }
        if (String.isNotBlank(lastName)) {
            String lastNamePart = lastName.length() >= 4 ? lastName.substring(0, 4) : lastName;
            alias += lastNamePart.substring(0, 1).toUpperCase();
            if (lastNamePart.length() > 1) {
                alias += lastNamePart.substring(1).toLowerCase();
            }
        }
        
        // Ensure alias is not empty and not too long
        if (String.isBlank(alias)) {
            alias = 'GUser';
        }
        
        return alias.length() > 8 ? alias.substring(0, 8) : alias;
    }
    
    private String extractFirstName(String fullName) {
        if (String.isBlank(fullName)) {
            return 'Google';
        }
        
        List<String> nameParts = fullName.split(' ');
        return nameParts[0];
    }
    
    private String extractLastName(String fullName) {
        if (String.isBlank(fullName)) {
            return 'User';
        }
        
        List<String> nameParts = fullName.split(' ');
        if (nameParts.size() > 1) {
            return nameParts[nameParts.size() - 1];
        }
        return 'User';
    }
    
    private Id getDigiCreditProfileId() {
        // Try to find Digi-Credit profile first
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Digi-Credit Customer Profile' LIMIT 1];
        if (!profiles.isEmpty()) {
            return profiles[0].Id;
        }
        
        // Fallback to Customer Community User profile
        List<Profile> fallbackProfiles = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
        if (!fallbackProfiles.isEmpty()) {
            return fallbackProfiles[0].Id;
        }
        
        // Last resort - any community profile
        List<Profile> communityProfiles = [SELECT Id FROM Profile WHERE Name LIKE '%Community%' LIMIT 1];
        if (!communityProfiles.isEmpty()) {
            return communityProfiles[0].Id;
        }
        
        System.debug('No suitable community profile found');
        return null;
    }
}

//__________________________GenAI: Generated code ends here______________________________
