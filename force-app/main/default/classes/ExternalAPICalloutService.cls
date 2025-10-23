//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public with sharing class ExternalAPICalloutService {
    
    private static final String CREDIT_BUREAU_ENDPOINT = 'callout:Credit_Bureau_API';
    private static final Integer TIMEOUT_SECONDS = 30;
    private static final Integer MAX_RETRIES = 3;
    private static final Integer BASE_DELAY_MS = 1000;
    
    /**
     * Get credit bureau score for a customer
     * @param externalCustomerId External customer identifier
     * @return Decimal credit score from external API
     */
    public static Decimal getCreditBureauScore(String externalCustomerId) {
        if (String.isBlank(externalCustomerId)) {
            throw new ExternalAPIException('External Customer ID cannot be blank');
        }
        
        CreditScoreRequest requestData = buildCreditScoreRequest(externalCustomerId);
        CreditScoreResponse response = callCreditBureauAPIWithRetry(requestData);
        
        if (response != null && response.credit_score != null) {
            // Cache the response for future use
            cacheAPIResponse(externalCustomerId, response);
            return response.credit_score;
        }
        
        return 0;
    }
    
    /**
     * Call credit bureau API with retry mechanism
     * @param requestData Credit score request data
     * @return CreditScoreResponse from API
     */
    private static CreditScoreResponse callCreditBureauAPIWithRetry(CreditScoreRequest requestData) {
        Integer attempt = 0;
        Exception lastException;
        
        while (attempt < MAX_RETRIES) {
            try {
                return callCreditBureauAPI(requestData);
            } catch (CalloutException e) {
                lastException = e;
                attempt++;
                
                if (attempt < MAX_RETRIES) {
                    // Exponential backoff delay
                    Integer delay = BASE_DELAY_MS * (Integer) Math.pow(2, attempt - 1);
                    System.debug('API call failed, retrying in ' + delay + 'ms. Attempt: ' + attempt);
                    // Note: In actual implementation, you might use Queueable for delay
                }
            }
        }
        
        throw new ExternalAPIException('Max retries exceeded for credit bureau API: ' + lastException.getMessage());
    }
    
    /**
     * Make HTTP callout to credit bureau API
     * @param requestData Credit score request data
     * @return CreditScoreResponse from API
     */
    private static CreditScoreResponse callCreditBureauAPI(CreditScoreRequest requestData) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(CREDIT_BUREAU_ENDPOINT + '/credit-score/calculate');
        request.setMethod('POST');
        request.setHeader('Authorization', 'Bearer ' + getCreditBureauToken());
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('X-API-Version', '2.0');
        request.setBody(JSON.serialize(requestData));
        request.setTimeout(TIMEOUT_SECONDS * 1000);
        
        Http http = new Http();
        HttpResponse response = http.send(request);
        
        // Log the API call for monitoring
        logAPICall('CreditBureau', 'getCreditScore', requestData.customer_id, 
                  response.getStatusCode(), System.currentTimeMillis());
        
        if (response.getStatusCode() == 200) {
            return (CreditScoreResponse) JSON.deserialize(response.getBody(), CreditScoreResponse.class);
        } else if (response.getStatusCode() == 404) {
            System.debug('Customer not found in credit bureau: ' + requestData.customer_id);
            return null;
        } else {
            throw new CalloutException('Credit Bureau API Error: ' + response.getStatusCode() + ' - ' + response.getBody());
        }
    }
    
    /**
     * Build credit score request from customer data
     * @param externalCustomerId External customer ID
     * @return CreditScoreRequest object
     */
    private static CreditScoreRequest buildCreditScoreRequest(String externalCustomerId) {
        // Get customer data for API request
        Account customer = getCustomerForAPIRequest(externalCustomerId);
        
        CreditScoreRequest request = new CreditScoreRequest();
        request.customer_id = externalCustomerId;
        request.request_id = generateRequestId();
        request.calculation_date = String.valueOf(Date.today());
        
        // Build customer data object
        request.customer_data = new CustomerData();
        request.customer_data.name = customer.Name;
        request.customer_data.phone = customer.Phone;
        
        // Build address object
        if (String.isNotBlank(customer.BillingStreet) || String.isNotBlank(customer.BillingCity)) {
            request.customer_data.address = new Address();
            request.customer_data.address.street = customer.BillingStreet;
            request.customer_data.address.city = customer.BillingCity;
            request.customer_data.address.state = customer.BillingState;
            request.customer_data.address.zip = customer.BillingPostalCode;
        }
        
        return request;
    }
    
    /**
     * Get customer data for API request
     * @param externalCustomerId External customer ID
     * @return Account record with required fields
     */
    private static Account getCustomerForAPIRequest(String externalCustomerId) {
        List<Account> customers = [
            SELECT Id, Name, Phone, BillingStreet, BillingCity, BillingState, BillingPostalCode
            FROM Account 
            WHERE External_Customer_ID__c = :externalCustomerId 
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        if (customers.isEmpty()) {
            throw new ExternalAPIException('Customer not found with External ID: ' + externalCustomerId);
        }
        
        return customers[0];
    }
    
    /**
     * Get access token for credit bureau API
     * @return Access token string
     */
    private static String getCreditBureauToken() {
        // Implementation would depend on authentication method
        // This could involve JWT token generation, OAuth flow, etc.
        // For now, return placeholder - in real implementation, this would
        // handle token generation and refresh
        return 'placeholder_credit_bureau_token';
    }
    
    /**
     * Generate unique request ID for API tracking
     * @return Unique request identifier
     */
    private static String generateRequestId() {
        return 'REQ_' + String.valueOf(System.currentTimeMillis()) + '_' + 
               String.valueOf(Math.random()).substring(2, 8);
    }
    
    /**
     * Cache API response for future use
     * @param customerId Customer identifier
     * @param response API response to cache
     */
    private static void cacheAPIResponse(String customerId, CreditScoreResponse response) {
        try {
            // Implementation for caching mechanism
            // This could use Platform Cache, Custom Objects, or other storage
            System.debug('Caching API response for customer: ' + customerId + 
                        ', Score: ' + response.credit_score);
        } catch (Exception e) {
            System.debug('Error caching API response: ' + e.getMessage());
            // Don't fail the main process for caching errors
        }
    }
    
    /**
     * Log API call for monitoring and analytics
     * @param serviceName Name of the external service
     * @param operation API operation called
     * @param customerId Customer identifier
     * @param statusCode HTTP response status code
     * @param responseTime Response time in milliseconds
     */
    private static void logAPICall(String serviceName, String operation, String customerId, 
                                  Integer statusCode, Long responseTime) {
        try {
            // Implementation for API call logging
            // This could create records in a custom object for monitoring
            System.debug('API Call Log - Service: ' + serviceName + 
                        ', Operation: ' + operation + 
                        ', Customer: ' + customerId + 
                        ', Status: ' + statusCode + 
                        ', Response Time: ' + responseTime + 'ms');
        } catch (Exception e) {
            System.debug('Error logging API call: ' + e.getMessage());
        }
    }
    
    /**
     * Check if external API is available
     * @return Boolean indicating API availability
     */
    public static Boolean isAPIAvailable() {
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(CREDIT_BUREAU_ENDPOINT + '/health');
            request.setMethod('GET');
            request.setTimeout(5000); // Short timeout for health check
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            return response.getStatusCode() == 200;
        } catch (Exception e) {
            System.debug('API health check failed: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Wrapper class for credit score API request
     */
    public class CreditScoreRequest {
        public String customer_id;
        public String request_id;
        public CustomerData customer_data;
        public String calculation_date;
    }
    
    /**
     * Wrapper class for customer data in API request
     */
    public class CustomerData {
        public String name;
        public String phone;
        public Address address;
    }
    
    /**
     * Wrapper class for address data
     */
    public class Address {
        public String street;
        public String city;
        public String state;
        public String zip;
    }
    
    /**
     * Wrapper class for credit score API response
     */
    public class CreditScoreResponse {
        public String request_id;
        public String customer_id;
        public Decimal credit_score;
        public List<ScoreFactor> score_factors;
        public String calculation_date;
        public String expires_at;
        public String confidence_level;
    }
    
    /**
     * Wrapper class for score factors in API response
     */
    public class ScoreFactor {
        public String factor;
        public String impact;
        public Integer weight;
    }
    
    /**
     * Custom exception for external API errors
     */
    public class ExternalAPIException extends Exception {
        // Custom exception for external API specific errors
    }
}

//__________________________GenAI: Generated code ends here______________________________
