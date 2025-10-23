//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

global class DigiCreditGoogleRegistrationHandler implements Auth.RegistrationHandler {
    
    global User createUser(Id portalId, Auth.UserData data) {
        System.debug('Creating user with Google data: ' + JSON.serialize(data));
        
        // Check if user already exists
        List<User> existingUsers = [SELECT Id, IsActive FROM User WHERE Email = :data.email LIMIT 1];
        if (!existingUsers.isEmpty() && existingUsers[0].IsActive) {
            System.debug('Existing active user found: ' + existingUsers[0].Id);
            return existingUsers[0];
        }
        
        // Create Person Account first
        Account personAccount = createPersonAccount(data);
        
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
        
        // Set community profile
        Id profileId = getDigiCreditProfileId();
        if (profileId != null) {
            newUser.ProfileId = profileId;
        }
        
        // Link to Person Account if created
        if (personAccount != null) {
            newUser.ContactId = personAccount.PersonContactId;
        }
        
        System.debug('Creating user: ' + JSON.serialize(newUser));
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
            Account personAccount = new Account();
            personAccount.FirstName = String.isNotBlank(data.firstName) ? data.firstName : extractFirstName(data.fullName);
            personAccount.LastName = String.isNotBlank(data.lastName) ? data.lastName : extractLastName(data.fullName);
            personAccount.PersonEmail = data.email;
            
            // Set Person Account Record Type
            List<RecordType> personAccountRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1];
            if (!personAccountRT.isEmpty()) {
                personAccount.RecordTypeId = personAccountRT[0].Id;
            }
            
            insert personAccount;
            
            // Retrieve the account with PersonContactId
            Account insertedAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :personAccount.Id LIMIT 1];
            System.debug('Created Person Account: ' + insertedAccount.Id + ' with ContactId: ' + insertedAccount.PersonContactId);
            return insertedAccount;
            
        } catch (Exception e) {
            System.debug('Error creating Person Account: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return null;
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
