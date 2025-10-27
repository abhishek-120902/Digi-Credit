# Customer Detail View Component - Implementation Guide

## Overview
The `customerDetailView` Lightning Web Component provides a professional, agent-focused view of customer information with only relevant fields displayed in a clean, well-organized layout.

## Component Features

### ✅ Key Features Implemented
- **Selective Field Display**: Shows only relevant fields for agents (no information overload)
- **Professional UI**: Clean, card-based layout with proper spacing and alignment
- **Credit Score Integration**: Prominent credit score display with color-coded status
- **Quick Actions**: Easy access to related records and common tasks
- **Credit History Modal**: Detailed credit score history with breakdown
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Error Handling**: Graceful error states and loading indicators
- **Navigation Integration**: Seamless navigation to related records

### 🎨 UI Components
1. **Header Section**: Customer name, ID, and action buttons
2. **Basic Information Card**: Name, phone, email, age, type, industry
3. **Account Details Card**: External ID, owner, created date
4. **Credit Score Card**: Current score, status, last calculation
5. **Quick Actions Card**: View cases, billing records, etc.
6. **Credit History Modal**: Detailed score breakdown table

## Fields Displayed

### Customer Information
- **Customer Name**: Primary account name
- **Phone**: Formatted phone number with click-to-call
- **Email**: Formatted email with click-to-email
- **Age**: Customer age in years
- **Account Type**: Business account type
- **Industry**: Customer industry

### Account Details
- **External Customer ID**: Unique identifier (styled as code)
- **Account Owner**: Salesforce user who owns the account
- **Created Date**: When the account was created

### Credit Information
- **Current Credit Score**: Large, color-coded display
- **Credit Score Status**: Poor/Good/Excellent badge
- **Last Calculation**: When score was last updated

## Usage Instructions

### 1. Deploy the Component
```bash
# Deploy the component to your org
sf project deploy start --source-dir force-app/main/default/lwc/customerDetailView --target-org your-org-alias
```

### 2. Add to Agent Community Pages

**Option A: Replace Record Detail Component**
1. In Experience Builder, go to your Customer Detail page
2. Remove the existing Record Detail component
3. Add the **Customer Detail View** component from Custom Components
4. Configure the recordId property to `{!recordId}`

**Option B: Add to Custom Page**
1. Create a new Standard Page in Experience Builder
2. Add the **Customer Detail View** component
3. Set the recordId property to the Account ID

### 3. Add to Lightning Record Pages
1. Go to **Setup > Object Manager > Account > Lightning Record Pages**
2. Edit your agent-specific Account record page
3. Add the **Customer Detail View** component
4. Remove or replace the standard Record Detail component

### 4. Configure Navigation
Update your community navigation to use the new component:
- **Customer Management page**: Add the component for detailed view
- **Agent Dashboard**: Link customer names to the detail view
- **Search Results**: Navigate to detail view on customer selection

## Component Configuration

### Available Properties
- **recordId**: The Account ID to display (automatically passed in most contexts)

### Automatic RecordId Resolution
The component intelligently resolves the recordId from multiple sources:

1. **@api recordId**: Direct property assignment (highest priority)
2. **URL State Parameters**: `currentPageReference.state.recordId`
3. **URL Attributes**: `currentPageReference.attributes.recordId`
4. **Custom URL Parameters**: `c__recordId` or `id` in URL state
5. **URL Path Extraction**: Extracts 15-18 character Salesforce IDs from custom URLs

**Supported URL Patterns:**
- Standard Record Pages: `/lightning/r/Account/{recordId}/view`
- Community Object Pages: `/customer/{recordId}`
- Custom URLs with state: `?recordId={accountId}`
- Custom parameter URLs: `?c__recordId={accountId}`

This makes the component flexible for use in:
- Standard Lightning Record Pages
- Community Object Pages
- Custom Community Pages with URL parameters
- Embedded components with dynamic recordId

### Styling Customization
The component uses CSS custom properties that can be overridden:

```css
/* In your community theme or custom CSS */
.customer-detail-container {
    --primary-color: #0176d3;
    --success-color: #04844b;
    --warning-color: #fe9339;
    --error-color: #c23934;
}
```

## Integration Points

### 1. Credit Score Calculation
- **Recalculate Button**: Triggers `CreditScoreCalculationService.calculateCreditScore()`
- **Real-time Updates**: Component refreshes after score calculation
- **API Integration**: Includes external API scores in calculation

### 2. Navigation Actions
- **Edit Customer**: Opens standard Salesforce edit page
- **View Cases**: Navigates to related Cases
- **View Billing Records**: Shows billing history
- **Credit History**: Modal with detailed score breakdown

### 3. Data Sources
- **Lightning Data Service**: Real-time data binding with automatic refresh
- **Apex Methods**: Credit score history and calculation services
- **Navigation Service**: Seamless navigation between records

## Security & Permissions

### Required Permissions (Already in DigiCredit_Agent_Access)
- **Account**: Read access with View All Records
- **Credit_Score__c**: Read access to all credit scores
- **Billing_Record__c**: Read access to billing data
- **Apex Classes**: Access to CreditScoreCalculationService

### Field-Level Security
The component respects field-level security:
- Fields without read access won't display
- "Not provided" shown for inaccessible fields
- Graceful handling of missing permissions

## Testing the Component

### 1. Create Test Data
```apex
// Create test account with all fields
Account testAccount = new Account(
    Name = 'Test Customer Premium',
    Phone = '(555) 123-4567',
    Email__c = 'test@example.com',
    Age__c = 35,
    Type = 'Customer - Direct',
    Industry = 'Technology',
    External_Customer_ID__c = 'PREMIUM_001'
);
insert testAccount;
```

### 2. Test Credit Score Integration
1. Navigate to the customer detail view
2. Click **Recalculate Score** button
3. Verify score updates with external API data
4. Check **View Credit History** shows breakdown

### 3. Test Responsive Design
1. View on desktop (full layout)
2. Test on tablet (responsive grid)
3. Check mobile view (stacked layout)
4. Verify all buttons and actions work

## Troubleshooting

### Common Issues

**1. Component Not Visible**
- Check permission set assignment
- Verify component is exposed in metadata
- Confirm user has community access

**2. Fields Not Displaying**
- Check field-level security
- Verify field API names in component
- Confirm object permissions

**3. Credit Score Not Loading**
- Check CreditScoreCalculationService permissions
- Verify External_Customer_ID__c field exists
- Test API integration separately

**4. Navigation Not Working**
- Verify NavigationMixin import
- Check related list permissions
- Confirm record access

### Debug Steps
1. **Check Browser Console**: Look for JavaScript errors
2. **Debug Logs**: Enable debug logs for the user
3. **Field Access**: Test field visibility in standard UI
4. **Permissions**: Verify all required permissions assigned

## Customization Options

### 1. Add More Fields
Edit the component to include additional Account fields:

```javascript
// Add to ACCOUNT_FIELDS array
import ACCOUNT_WEBSITE_FIELD from '@salesforce/schema/Account.Website';

// Add getter method
get accountWebsite() {
    return getFieldValue(this.account.data, ACCOUNT_WEBSITE_FIELD);
}
```

### 2. Modify Layout
Update the HTML template to change the layout:
- Add new cards for additional information
- Rearrange existing sections
- Modify responsive breakpoints

### 3. Custom Actions
Add new quick actions:

```javascript
// Add new action handler
handleCustomAction() {
    // Your custom logic here
}
```

### 4. Styling Changes
Modify the CSS file to match your brand:
- Update color scheme
- Change fonts and spacing
- Modify card layouts

## Performance Considerations

### Optimizations Implemented
- **Lightning Data Service**: Efficient data caching and sharing
- **Conditional Rendering**: Only render when data is available
- **Lazy Loading**: Credit history loaded on demand
- **Responsive Images**: Optimized for different screen sizes

### Best Practices
- Component uses `@wire` for automatic data refresh
- Error boundaries prevent component crashes
- Loading states provide user feedback
- Minimal API calls with proper caching

## Integration with Existing Components

### Works With
- **agentDashboard**: Link customer names to detail view
- **agentTools**: Complementary agent functionality
- **creditScoreDisplay**: Consistent credit score presentation

### Navigation Flow
1. **Agent Dashboard** → Customer search → **Customer Detail View**
2. **Customer Management** → Customer list → **Customer Detail View**
3. **Case Management** → Related customer → **Customer Detail View**

## Deployment Checklist

- [ ] Component deployed to org
- [ ] Permission set updated with component access
- [ ] Added to agent community pages
- [ ] Navigation configured
- [ ] Test data created
- [ ] Functionality tested
- [ ] Mobile responsiveness verified
- [ ] Error handling tested
- [ ] Performance validated

## Support and Maintenance

### Regular Maintenance
- Monitor component performance
- Update field mappings as needed
- Review and update styling
- Test with new Salesforce releases

### Enhancement Requests
- Additional field requirements
- New quick actions
- Layout modifications
- Integration with new systems

The Customer Detail View component provides a professional, efficient way for agents to view customer information without the clutter of unnecessary fields, while maintaining full functionality and integration with the DigiCredit system.
