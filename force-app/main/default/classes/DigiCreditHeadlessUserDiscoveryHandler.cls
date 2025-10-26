public class DigiCreditHeadlessUserDiscoveryHandler implements Auth.HeadlessUserDiscoveryHandler {
    
    public Auth.HeadlessUserDiscoveryResponse discoverUserFromLoginHint(
        Id networkId, 
        String loginHint, 
        Auth.VerificationAction verificationAction, 
        String verificationMethod, 
        Map<String, String> attributes
    ) {
        // Simple implementation for user discovery
        String email = loginHint;
        
        // Check if user exists
        List<User> existingUsers = [SELECT Id, Username FROM User WHERE Email = :email LIMIT 1];
        
        Auth.HeadlessUserDiscoveryResponse response = new Auth.HeadlessUserDiscoveryResponse();
        
        if (!existingUsers.isEmpty()) {
            // User exists, set the username for login
            response.setUsername(existingUsers[0].Username);
        }
        // If user doesn't exist, username remains null which allows registration
        
        return response;
    }
}
