# DigiCredit Agent Community Deployment Guide

## Overview
This guide provides step-by-step instructions for deploying and configuring the Agent Community for the DigiCredit system. The Agent Community allows internal agents to access customer information and manage assigned service requests.

## Components Deployed

### 1. External API Integration
- **Service Class**: `ExternalAPICalloutService.cls` (Enhanced with direct endpoint configuration)
- **Integration**: Credit score calculation now includes external API data
- **Named Credential**: Manual setup required (see Step 2 below)

### 2. Agent Community Network
- **Network Configuration**: `DigiCreditAgent.network-meta.xml`
- **URL Path**: `/agents`
- **Features**: Agent-specific navigation, case management, customer access

### 3. Security & Permissions
- **Permission Set**: `DigiCredit_Agent_Access.permissionset-meta.xml`
- **Object Access**: Account (view all), Case (assigned only), Credit Score data
- **Field Permissions**: Read access to customer data, edit access to case management

### 4. Backend Services
- **Agent Service**: `AgentService.cls`
  - Case management for assigned cases only
  - Customer data access (view all customers)
  - Dashboard statistics and analytics
  - Case search and filtering capabilities

### 5. Lightning Web Components
- **Agent Dashboard**: `agentDashboard` (New comprehensive dashboard)
- **Agent Tools**: `agentTools` (Enhanced existing component)

## Deployment Steps

### Step 1: Deploy Metadata Components
```bash
# Deploy all components to your org
sf project deploy start --source-dir force-app --target-org your-org-alias

# Or deploy specific components
sf project deploy start --metadata NamedCredential:External_Credit_API --target-org your-org-alias
sf project deploy start --metadata Network:DigiCreditAgent --target-org your-org-alias
sf project deploy start --metadata PermissionSet:DigiCredit_Agent_Access --target-org your-org-alias
```

### Step 2: External API Configuration

**Option A: Postman Mock API (Recommended for Real Testing)**
1. Follow the **POSTMAN_MOCK_API_SETUP_GUIDE.md** to create a free Postman mock server
2. Get your Postman mock URL (e.g., `https://[mock-id].mock.pstmn.io`)
3. Update the ExternalAPICalloutService.cls endpoint:
   ```apex
   private static final String CREDIT_BUREAU_ENDPOINT = 'https://[your-mock-id].mock.pstmn.io';
   ```
4. Deploy the updated code
5. Test with real HTTP calls to external API

**Option B: Internal Mock Service (Quick Testing)**
- The system includes a **MockExternalAPIService** that automatically provides realistic credit scores
- In sandbox environments, the mock API is used automatically
- No external API setup required for testing

**Option C: Production with Real API**
1. Navigate to **Setup > Named Credentials**
2. Click **New** to create a new Named Credential
3. Configure the following settings:
   - **Label**: External Credit API
   - **Name**: External_Credit_API
   - **URL**: Your actual API endpoint
   - **Identity Type**: Named Principal
   - **Authentication Protocol**: Password Authentication (or OAuth as needed)
   - **Username**: Your API username
   - **Password**: Your API password/token
   - **Generate Authorization Header**: Checked
4. Save the Named Credential
5. The system will automatically use the real API in production environments

### Step 3: Activate Agent Community
1. Navigate to **Setup > All Communities**
2. Find **DigiCreditAgent** community
3. Click **Activate** if not already active
4. Configure community settings:
   - **Branding**: Upload logo and customize theme
   - **Pages**: Add agent dashboard and tools components
   - **Navigation**: Verify menu items are correctly configured

### Step 4: Create Agent Users
1. Create internal users for agents
2. Assign appropriate profiles (recommend creating custom Agent profile)
3. Assign **DigiCredit Agent Access** permission set
4. Enable community access for agent users

### Step 5: Configure Case Assignment
1. Navigate to **Setup > Case Assignment Rules**
2. Create rules to automatically assign cases to agents
3. Configure case queues if using queue-based assignment
4. Set up case escalation rules if needed

### Step 6: Test Agent Access
1. Login as an agent user
2. Navigate to the agent community (`/agents`)
3. Verify access to:
   - Dashboard with statistics
   - Customer search and view capabilities
   - Assigned cases management
   - Case creation and updates

## Security Configuration

### Agent Access Levels
- **Accounts**: View all customer records
- **Cases**: View and edit only assigned cases
- **Credit Scores**: Read-only access to all credit score data
- **Billing Records**: Read-only access for customer support

### Sharing Rules (Manual Setup Required)
1. **Case Sharing**: 
   - Navigate to **Setup > Sharing Settings**
   - Create sharing rule: Cases owned by agents are visible to agent role hierarchy
   - Ensure agents can only see their assigned cases

2. **Account Sharing**:
   - Agents need "View All" access to accounts (configured in permission set)
   - No additional sharing rules needed

## Component Configuration

### Agent Dashboard Component
The `agentDashboard` component provides:
- **Overview Tab**: Statistics and recent activity
- **Cases Tab**: Assigned cases with search and filtering
- **Customers Tab**: Customer directory with credit scores

To add to community pages:
1. Go to **Community Builder**
2. Add **Agent Dashboard** component to desired pages
3. Configure component properties as needed

### Agent Tools Component
The enhanced `agentTools` component includes:
- Customer search functionality
- Credit score recalculation
- Bulk processing capabilities
- Case management integration

## External API Integration

### Mock API Service (For Testing)
The system includes a **MockExternalAPIService** that provides realistic credit scores without requiring an external API:

**How it works:**
- Automatically detects sandbox environments and uses mock data
- Provides consistent, realistic credit scores based on customer ID patterns
- Supports different customer tiers (PREMIUM, STANDARD, BASIC)
- Generates scores between 75-225 points

**Testing Credit Score Calculation:**
1. Create test customers with External_Customer_ID__c values like:
   - `PREMIUM_001` → Returns 200 points
   - `STANDARD_001` → Returns 150 points  
   - `BASIC_001` → Returns 100 points
   - `TEST_001` → Returns calculated score (75-225 range)

2. Calculate credit scores and verify the external API component is included:
   - Base Score: 300
   - Internal Fields: Up to 150 points
   - Billing History: Up to 150 points
   - **External API**: 75-225 points (from mock service)
   - **Total**: 525-825 points possible

**Example Calculation:**
- Customer with External_Customer_ID__c = "PREMIUM_001"
- Base: 300 + Internal: 150 + Billing: 100 + API: 200 = **750 total score**

### Real API Configuration (Production)
1. **Endpoint Setup**: Configure the actual external credit bureau API endpoint
2. **Authentication**: Set up proper authentication (OAuth, API Key, etc.)
3. **Error Handling**: The service includes retry logic and graceful error handling
4. **Fallback**: If real API fails, system automatically falls back to mock service

### API Response Format
Expected JSON response format:
```json
{
  "request_id": "REQ_123456",
  "customer_id": "CUST_001",
  "credit_score": 175,
  "calculation_date": "2024-01-15",
  "confidence_level": "High"
}
```

## Monitoring and Maintenance

### Debug Logs
Monitor the following for issues:
- `ExternalAPICalloutService`: API integration errors
- `AgentService`: Case and customer access issues
- `CreditScoreCalculationService`: Score calculation with API data

### Performance Monitoring
- Monitor API callout limits and response times
- Track case assignment and resolution metrics
- Monitor community user adoption and usage patterns

## Troubleshooting

### Common Issues

1. **Agents Cannot Access Community**
   - Verify user has community access enabled
   - Check permission set assignment
   - Confirm community is activated

2. **API Integration Failures**
   - Check Named Credential configuration
   - Verify API endpoint accessibility
   - Review debug logs for specific error messages

3. **Case Access Issues**
   - Verify case assignment rules
   - Check sharing settings
   - Confirm agent user permissions

4. **Component Not Loading**
   - Check Lightning component security settings
   - Verify Apex class permissions in permission set
   - Review browser console for JavaScript errors

### Support Contacts
- **Technical Issues**: Contact Salesforce Administrator
- **API Issues**: Contact External Credit Bureau Support
- **User Training**: Contact Community Manager

## Future Enhancements

### Planned Features
1. **Advanced Analytics**: Enhanced reporting and dashboards
2. **Mobile Optimization**: Improved mobile experience for agents
3. **AI Integration**: Automated case routing and suggestions
4. **Real-time Notifications**: Push notifications for case updates

### Customization Options
- **Custom Fields**: Add agent-specific fields to cases and accounts
- **Workflow Automation**: Implement additional business process automation
- **Integration Expansion**: Connect additional external data sources
- **Reporting Enhancement**: Create custom reports and dashboards

## Conclusion

The Agent Community provides a comprehensive platform for internal agents to manage customer relationships and service requests effectively. The integration with external credit bureau APIs ensures agents have access to the most current and complete customer credit information.

For additional support or customization requests, please contact your Salesforce development team.
