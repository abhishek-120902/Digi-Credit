# Named Credential Setup Instructions for Postman Mock API

## Based on Your Screenshot Configuration

I can see you're setting up the Named Credential in Salesforce. Here's how to complete the configuration:

## Step-by-Step Configuration

### 1. External Credential Configuration
For the "External Credential" dropdown (currently showing "Select an Option"):

**Option A: Create New External Credential (Recommended)**
1. Click on "Select an Option" dropdown
2. Select "Create New External Credential"
3. In the External Credential dialog:
   - **Label**: `Postman Mock API Auth`
   - **Name**: `Postman_Mock_API_Auth`
   - **Authentication Protocol**: Select **"Custom"**
   - **Custom Headers**: Leave empty (no authentication needed)
   - Click **Save**

**Option B: Use Anonymous Authentication**
1. Click on "Select an Option" dropdown
2. If you see "Anonymous" option, select that
3. This is simpler for mock APIs that don't need authentication

### 2. Complete the Named Credential Form

Based on your current configuration:
- **Label**: `Postman Mock API` ✅ (looks good)
- **Name**: `Postman_Mock_API` ✅ (looks good)
- **URL**: `https://e4e21982-7a12-4cd8-b0d1-29b4a9ebe6d9.mock.pstmn.io` ✅ (your Postman mock URL)

**Additional Settings:**
- **Generate Authorization Header**: **UNCHECK** this box (Postman mock doesn't need auth)
- **Allow Formulas in HTTP Header**: Leave **UNCHECKED**
- **Allow Formulas in HTTP Body**: Leave **UNCHECKED**
- **Outbound Network Connection**: Leave as **"--None--"**

### 3. Save the Configuration
Click **Save** to create the Named Credential

## Alternative: Legacy Named Credential (Simpler)

If you're having trouble with the new format, use the Legacy approach:

1. **Cancel the current dialog**
2. Go to **Setup > Named Credentials & External Credentials**
3. Click **"New Legacy"** instead of "New"
4. Configure:
   - **Label**: `Postman Mock API`
   - **Name**: `Postman_Mock_API`
   - **URL**: `https://e4e21982-7a12-4cd8-b0d1-29b4a9ebe6d9.mock.pstmn.io`
   - **Identity Type**: `Anonymous`
   - **Authentication Protocol**: `No Authentication`
   - **Generate Authorization Header**: **UNCHECKED**

## After Creating the Named Credential

### Update Your Salesforce Code
Once the Named Credential is created, update your ExternalAPICalloutService:

```apex
// Change this line in ExternalAPICalloutService.cls
private static final String CREDIT_BUREAU_ENDPOINT = 'callout:Postman_Mock_API';
```

### Test the Integration
1. Create a test Account with `External_Customer_ID__c` = `"PREMIUM_001"`
2. Run credit score calculation
3. Check debug logs to verify API calls are working
4. Verify the API score component shows 200 points

## Troubleshooting

**If you get authentication errors:**
- Make sure "Generate Authorization Header" is unchecked
- Verify the External Credential is set to "Custom" or "Anonymous"

**If you get 404 errors:**
- Verify your Postman mock server URL is correct
- Test the URL directly in Postman first

**If you get permission errors:**
- Make sure your user has "Modify All Data" or the Named Credential is accessible to your profile

Your Postman mock API URL looks correct, so once the Named Credential is properly configured, the integration should work perfectly!
