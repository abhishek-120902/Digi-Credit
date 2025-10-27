# Postman Mock API Setup Guide for DigiCredit External API

## Overview
This guide shows you how to create a free mock API using Postman that simulates the external credit bureau API for the DigiCredit system.

## Step 1: Create Postman Account (Free)
1. Go to [https://www.postman.com/](https://www.postman.com/)
2. Click **Sign Up for Free**
3. Create your account using email or Google/GitHub
4. Verify your email address

## Step 2: Create a New Collection
1. Open Postman and click **Collections** in the left sidebar
2. Click **Create Collection**
3. Name it: `DigiCredit External API`
4. Add description: `Mock API for DigiCredit external credit score integration`
5. Click **Create**

## Step 3: Create API Endpoints

**Important Note about URL Variable:**
- When creating requests, use `{{url}}/endpoint-path` format
- The `{{url}}` is a Postman variable that will be automatically replaced with your mock server URL
- Don't worry about the actual URL value yet - Postman will handle this when you create the mock server

### Endpoint 1: Credit Score Calculation
1. In your collection, click **Add a request**
2. Name the request: `Calculate Credit Score`
3. Set method to **POST**
4. Set URL to: `{{url}}/credit-score/calculate`
   - **Note**: `{{url}}` is a variable - don't replace it with actual URL yet
5. Go to **Headers** tab and add:
   - `Content-Type`: `application/json`
   - `Authorization`: `Bearer {{token}}`

6. Go to **Body** tab, select **raw** and **JSON**, add this example request:
```json
{
  "customer_id": "PREMIUM_001",
  "request_id": "REQ_123456789",
  "customer_data": {
    "name": "John Doe",
    "phone": "+1234567890",
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip": "10001"
    }
  },
  "calculation_date": "2024-01-15"
}
```

7. Go to **Examples** tab and click **Add Example**
8. Name it: `Premium Customer Response`
9. Set the response body to:
```json
{
  "request_id": "REQ_123456789",
  "customer_id": "PREMIUM_001",
  "credit_score": 200,
  "calculation_date": "2024-01-15",
  "expires_at": "2024-02-15",
  "confidence_level": "High",
  "score_factors": [
    {
      "factor": "Payment History",
      "impact": "Positive",
      "weight": 35
    },
    {
      "factor": "Credit Utilization",
      "impact": "Positive",
      "weight": 30
    }
  ]
}
```

10. Set Status Code to `200 OK`
11. Click **Save Example**

### Create Additional Examples
Repeat step 7-11 to create more examples:

**Standard Customer Example:**
- Name: `Standard Customer Response`
- Request body: Change `customer_id` to `"STANDARD_001"`
- Response body: Change `credit_score` to `150`

**Basic Customer Example:**
- Name: `Basic Customer Response`  
- Request body: Change `customer_id` to `"BASIC_001"`
- Response body: Change `credit_score` to `100`

**Error Example:**
- Name: `Customer Not Found`
- Response body:
```json
{
  "error": "Customer not found",
  "error_code": "CUSTOMER_NOT_FOUND",
  "message": "No customer found with the provided ID"
}
```
- Status Code: `404 Not Found`

### Endpoint 2: Health Check
1. Add another request to the collection
2. Name: `Health Check`
3. Method: **GET**
4. URL: `{{url}}/health`
5. **No Body Required** (GET request - leave Body tab empty)
6. Go to **Examples** tab and click **Add Example**
7. Name it: `Healthy Response`
8. Set the response body to:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "2.0",
  "service": "DigiCredit External API",
  "uptime": "99.9%"
}
```
9. Set Status Code to `200 OK`
10. Click **Save Example**

## Step 4: Create Mock Server
1. In your collection, click the **...** (three dots) menu
2. Select **Mock collection**
3. Configure mock server:
   - **Mock Server Name**: `DigiCredit External API Mock`
   - **Environment**: Create new environment or select existing
   - **Make mock server private**: Leave unchecked (for free tier)
4. Click **Create Mock Server**

## Step 5: Get Your Mock API URL
1. After creating the mock server, Postman will show you the mock URL
2. It will look like: `https://[mock-id].mock.pstmn.io`
3. **Copy this URL** - you'll need it for Salesforce configuration

## Step 6: Test Your Mock API
1. Open a new tab in Postman
2. Create a POST request to: `https://[your-mock-id].mock.pstmn.io/credit-score/calculate`
3. Set headers:
   - `Content-Type`: `application/json`
4. Set body (raw JSON):
```json
{
  "customer_id": "PREMIUM_001",
  "request_id": "TEST_123",
  "customer_data": {
    "name": "Test Customer"
  },
  "calculation_date": "2024-01-15"
}
```
5. Send the request - you should get the 200 response with credit_score: 200

## Step 7: Configure Salesforce Integration

### Option A: Update ExternalAPICalloutService (Recommended)
Replace the endpoint in your Salesforce code:
```apex
private static final String CREDIT_BUREAU_ENDPOINT = 'https://[your-mock-id].mock.pstmn.io';
```

### Option B: Create Named Credential
1. In Salesforce Setup, go to **Named Credentials**
2. Click **New**
3. Configure:
   - **Label**: `Postman Mock API`
   - **Name**: `Postman_Mock_API`
   - **URL**: `https://[your-mock-id].mock.pstmn.io`
   - **Identity Type**: `Anonymous`
   - **Authentication Protocol**: `No Authentication`
4. Save the Named Credential

## Step 8: Test Integration
1. In Salesforce, create a test Account with:
   - `External_Customer_ID__c` = `"PREMIUM_001"`
2. Run credit score calculation
3. Verify the API score component shows 200 points
4. Check debug logs to confirm API call success

## Advanced Configuration

### Adding Authentication (Optional)
If you want to simulate API key authentication:

1. In your Postman examples, add header:
   - `X-API-Key`: `your-test-api-key`

2. Update Salesforce code to include the header:
```apex
request.setHeader('X-API-Key', 'your-test-api-key');
```

### Dynamic Responses
Postman mock servers can return different responses based on:
- Request headers
- Request body content
- URL parameters

Use the `customer_id` in your request to get different scores:
- `PREMIUM_*` → 200 points
- `STANDARD_*` → 150 points  
- `BASIC_*` → 100 points

## Monitoring and Usage
1. In Postman, go to your mock server settings
2. View **Mock Calls** to see API usage
3. Monitor response times and success rates
4. Free tier includes 1,000 mock server calls per month

## Benefits of Using Postman Mock API
✅ **Real HTTP Endpoint**: Actual external API for testing  
✅ **Free Tier Available**: 1,000 calls/month at no cost  
✅ **Easy Configuration**: No complex setup required  
✅ **Realistic Testing**: Simulates real API behavior  
✅ **Multiple Scenarios**: Different responses for different inputs  
✅ **Monitoring**: Built-in analytics and call tracking  
✅ **Professional**: More realistic than internal mock service  

## Troubleshooting
- **404 Errors**: Check your mock server URL is correct
- **No Response**: Ensure your request matches the example format
- **Wrong Data**: Verify the `customer_id` matches your examples
- **Rate Limits**: Free tier has monthly limits - monitor usage

Your Postman mock API is now ready to use as a real external endpoint for the DigiCredit system!
