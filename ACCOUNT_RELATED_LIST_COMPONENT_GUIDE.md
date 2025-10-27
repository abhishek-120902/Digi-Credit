# Account Related List Component Guide

## Overview

The `accountRelatedList` Lightning Web Component provides a custom related list solution for Account records, displaying three key related lists with proper security restrictions for agent users.

## Component Features

### 1. Three Related Lists
- **Cases**: Shows cases assigned to the current agent for the account
- **Credit Score History**: Displays credit score history for the account
- **Billing Records**: Shows billing records for the account

### 2. Security Model
- **Agent Restrictions**: Cases are filtered to show only those assigned to the current logged-in agent
- **Data Access**: Full access to customer credit scores and billing records for service purposes
- **Permission-Based**: Respects Salesforce field-level and object-level security

### 3. Professional UI
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **SLDS Compliant**: Uses Salesforce Lightning Design System
- **Interactive Elements**: Clickable rows, hover effects, and navigation
- **Status Indicators**: Color-coded badges for case status, payment status, and score changes

## Component Structure

```
accountRelatedList/
├── accountRelatedList.js          # Main JavaScript controller
├── accountRelatedList.html        # HTML template
├── accountRelatedList.css         # Styling
└── accountRelatedList.js-meta.xml # Metadata configuration
```

## Configuration Properties

### Available Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `recordId` | String | - | Account ID (auto-populated on record pages) |
| `showCases` | Boolean | false | Display cases related list |
| `showCreditScores` | Boolean | false | Display credit score history |
| `showBillingRecords` | Boolean | false | Display billing records |
| `maxRecords` | Integer | 5 | Maximum records per list (1-20) |

### Usage Examples

#### On Account Record Page
```xml
<!-- Component automatically gets recordId from page context -->
<c-account-related-list 
    show-cases="true"
    show-credit-scores="true" 
    show-billing-records="true"
    max-records="10">
</c-account-related-list>
```

#### On App Page or Community
```xml
<!-- Manually specify recordId -->
<c-account-related-list 
    record-id="0013000000abcdefg"
    show-cases="true"
    show-credit-scores="false"
    show-billing-records="true"
    max-records="5">
</c-account-related-list>
```

## Data Requirements

### Required Objects and Fields

#### 1. Standard Case Object
- **Relationship**: AccountId (standard lookup to Account)
- **Security**: Cases filtered by `OwnerId = currentUserId`
- **Fields Used**:
  - CaseNumber
  - Subject
  - Status
  - CreatedDate

#### 2. Credit_Score__c Custom Object
- **Relationship**: Customer__c (lookup to Account)
- **Fields Required**:
  ```
  Customer__c (Lookup to Account)
  Total_Score__c (Number)
  Score_Status__c (Text - Poor/Good/Excellent)
  Calculation_Date__c (DateTime)
  Base_Score__c (Number)
  Internal_Fields_Score__c (Number)
  External_Billing_Score__c (Number)
  API_Score__c (Number)
  Is_Current__c (Checkbox)
  Missing_Fields__c (Text)
  ```

#### 3. Billing_Record__c Custom Object
- **Relationship**: Customer__c (lookup to Account)
- **Fields Required**:
  ```
  Customer__c (Lookup to Account)
  Billing_Id__c (Text - External ID)
  Bill_Due_Date__c (Date)
  Bill_Payment_Date__c (Date)
  Is_Paid_On_Time__c (Formula Boolean)
  Bill_Amount__c (Currency)
  Payment_Status__c (Text)
  ```

### Required Apex Methods

The component uses these methods from `AgentService` class:

```apex
// Cases - Security filtered by agent
@AuraEnabled(cacheable=true)
public static List<Case> getRecentCases(Id accountId, Integer limitRecords)

// Credit Score History
@AuraEnabled(cacheable=true)
public static List<Credit_Score__c> getCreditScoreHistory(Id accountId, Integer limitRecords)

// Billing Records
@AuraEnabled(cacheable=true)
public static List<Billing_Record__c> getRecentBillingRecords(Id accountId, Integer limitRecords)
```

## Deployment Instructions

### 1. Deploy Component Files
```bash
# Deploy the LWC component
sf project deploy start --source-dir force-app/main/default/lwc/accountRelatedList

# Deploy AgentService class (if not already deployed)
sf project deploy start --source-dir force-app/main/default/classes/AgentService.cls
```

### 2. Create Required Custom Objects

#### Credit_Score__c Object
```bash
# Create via Setup > Object Manager > New Custom Object
# Or deploy metadata files for the custom objects
```

#### Billing_Record__c Object
```bash
# Create via Setup > Object Manager > New Custom Object
# Or deploy metadata files for the custom objects
```

### 3. Set Up Permissions

#### Agent Permission Set
```xml
<!-- Add to DigiCredit_Agent_Access permission set -->
<objectPermissions>
    <allowRead>true</allowRead>
    <object>Credit_Score__c</object>
</objectPermissions>
<objectPermissions>
    <allowRead>true</allowRead>
    <object>Billing_Record__c</object>
</objectPermissions>
```

### 4. Add to Page Layouts

#### Lightning Record Page
1. Go to Setup > Lightning App Builder
2. Edit Account record page or create new one
3. Drag "Account Related List" component to page
4. Configure properties:
   - Show Cases: ✓
   - Show Credit Scores: ✓ 
   - Show Billing Records: ✓
   - Max Records: 5

#### Community Pages
1. Go to Experience Builder
2. Add component to Account detail pages
3. Configure recordId and display properties

## Component Behavior

### Data Loading
- **Wire Services**: Uses @wire decorators for reactive data loading
- **Automatic Refresh**: Data updates when underlying records change
- **Error Handling**: Graceful error display with user-friendly messages
- **Loading States**: Shows loading spinners during data fetch

### Navigation
- **Record Navigation**: Click rows to navigate to individual records
- **Related List Navigation**: "View All" buttons navigate to standard related lists
- **Breadcrumb Support**: Maintains navigation context

### Security Implementation

#### Case Security
```apex
// Only cases assigned to current agent
WHERE AccountId = :accountId AND OwnerId = :currentUserId
```

#### Data Access
- Credit scores: Full read access for customer service
- Billing records: Full read access for account management
- Field-level security: Respects user permissions

## Styling and Customization

### CSS Classes Available
```css
/* Main container */
.related-list-card

/* Table styling */
.related-list-table
.clickable-row

/* Status indicators */
.score-excellent, .score-good, .score-poor
.score-change-positive, .score-change-negative

/* Responsive breakpoints */
@media (max-width: 768px)
@media (max-width: 480px)
```

### Customization Options
1. **Colors**: Modify status badge colors in CSS
2. **Layout**: Adjust grid layout and card sizing
3. **Fields**: Add/remove fields by updating Apex methods and HTML
4. **Icons**: Change Lightning icons in HTML template

## Testing

### Unit Testing Scenarios
1. **Data Loading**: Test with valid Account ID
2. **Security**: Verify case filtering by agent
3. **Error Handling**: Test with invalid data
4. **Navigation**: Test record and related list navigation
5. **Responsive**: Test on different screen sizes

### Sample Test Data
```apex
// Create test account
Account testAccount = new Account(Name = 'Test Customer');
insert testAccount;

// Create test case assigned to current user
Case testCase = new Case(
    AccountId = testAccount.Id,
    Subject = 'Test Case',
    OwnerId = UserInfo.getUserId()
);
insert testCase;

// Create test credit score
Credit_Score__c testScore = new Credit_Score__c(
    Customer__c = testAccount.Id,
    Total_Score__c = 650,
    Score_Status__c = 'Good'
);
insert testScore;
```

## Troubleshooting

### Common Issues

#### 1. "No cases found" Message
- **Cause**: No cases assigned to current agent
- **Solution**: Assign cases to the agent user or create test cases

#### 2. "Credit score history not loading"
- **Cause**: Credit_Score__c object doesn't exist or no data
- **Solution**: Create custom object and add sample records

#### 3. "Permission denied" Errors
- **Cause**: Missing object or field permissions
- **Solution**: Update agent permission sets

#### 4. Component Not Visible
- **Cause**: Component not added to page or wrong configuration
- **Solution**: Check page layout and component properties

### Debug Steps
1. **Browser Console**: Check for JavaScript errors
2. **Developer Console**: Test Apex methods directly
3. **Permission Sets**: Verify agent has required permissions
4. **Data**: Confirm related records exist

## Performance Considerations

### Optimization Features
- **Cacheable Apex**: Uses `@AuraEnabled(cacheable=true)` for better performance
- **Limited Records**: Configurable record limits prevent large data sets
- **Wire Services**: Efficient data binding and updates
- **Lazy Loading**: Only loads data when component is visible

### Best Practices
- Keep `maxRecords` reasonable (5-20 records)
- Use indexes on lookup fields for better query performance
- Monitor SOQL query limits in high-volume environments

## Integration Points

### With Existing Components
- **customerDetailView**: Can be used alongside for comprehensive customer view
- **agentDashboard**: Provides summary data for agent workflow
- **creditScoreDisplay**: Complementary detailed credit analysis

### With Salesforce Features
- **Lightning Data Service**: Automatic record updates
- **Navigation Service**: Standard Salesforce navigation
- **Toast Events**: Standard notification system
- **Refresh API**: Supports manual and automatic refresh

## Future Enhancements

### Potential Improvements
1. **Filtering**: Add filters for date ranges, status, etc.
2. **Sorting**: Allow column sorting in tables
3. **Pagination**: Handle large data sets with pagination
4. **Export**: Add export functionality for data
5. **Real-time Updates**: Push notifications for new records

### Extensibility
- Component is designed for easy extension
- Additional related lists can be added following the same pattern
- Custom fields can be included by updating Apex methods
- Styling can be customized without affecting functionality

This component provides a robust, secure, and user-friendly solution for displaying Account-related data with proper agent access controls and professional UI design.
