public with sharing class MockExternalAPIService {
    
    /**
     * Mock external API service that simulates credit bureau responses
     * This allows testing without requiring an actual external API
     */
    
    /**
     * Get mock credit bureau score for a customer
     * @param externalCustomerId External customer identifier
     * @return Decimal credit score (simulated)
     */
    public static Decimal getMockCreditBureauScore(String externalCustomerId) {
        if (String.isBlank(externalCustomerId)) {
            return 0;
        }
        
        // Simulate different scores based on customer ID patterns
        // This provides realistic testing scenarios
        
        if (externalCustomerId.contains('PREMIUM')) {
            return 200; // High score for premium customers
        } else if (externalCustomerId.contains('STANDARD')) {
            return 150; // Medium score for standard customers
        } else if (externalCustomerId.contains('BASIC')) {
            return 100; // Lower score for basic customers
        } else {
            // Generate a consistent score based on customer ID hash
            Integer hash = Math.abs(externalCustomerId.hashCode());
            return 75 + Math.mod(hash, 150); // Score between 75-225
        }
    }
    
    /**
     * Simulate API response with realistic data structure
     * @param externalCustomerId External customer identifier
     * @return Mock API response object
     */
    public static MockAPIResponse getMockAPIResponse(String externalCustomerId) {
        MockAPIResponse response = new MockAPIResponse();
        response.request_id = 'MOCK_REQ_' + String.valueOf(System.currentTimeMillis());
        response.customer_id = externalCustomerId;
        response.credit_score = getMockCreditBureauScore(externalCustomerId);
        response.calculation_date = String.valueOf(Date.today());
        response.confidence_level = 'High';
        response.api_version = '2.0';
        response.response_time_ms = 150 + Math.mod(Math.abs(externalCustomerId.hashCode()), 100);
        
        return response;
    }
    
    /**
     * Check if we should use mock API (for testing/demo purposes)
     * @return Boolean indicating whether to use mock API
     */
    public static Boolean shouldUseMockAPI() {
        // Check if this is a sandbox or if mock mode is enabled
        Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
        return org.IsSandbox; // Use mock API in sandbox environments
    }
    
    /**
     * Mock API Response wrapper class
     */
    public class MockAPIResponse {
        public String request_id;
        public String customer_id;
        public Decimal credit_score;
        public String calculation_date;
        public String confidence_level;
        public String api_version;
        public Integer response_time_ms;
    }
}
