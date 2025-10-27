# Related Lists Setup Guide for CustomerDetailView Component

This guide explains how to set up the three related lists in the customerDetailView component: Cases, Credit Scores, and Billing Records.

## Overview

The customerDetailView component displays three related lists:
1. **Cases**: Related cases for this customer (with agent security restrictions)
2. **Credit Scores**: Credit score history for this customer
3. **Billing Records**: Billing history for this customer

## 1. Cases Related List Setup

### ✅ Status: Already Implemented

**Object**: Standard Case object
**Relationship**: AccountId (Standard lookup to Account)

**Apex Method**: `AgentService.getRecentCases()`
```apex
@AuraEnabled(cacheable=true)
public static List<Case> getRecentCases(Id accountId, Integer limitRecords) {
    // Security: Only returns cases assigned to current agent
    WHERE AccountId = :accountId AND OwnerId = :currentUserId
}
```

**Fields Displayed**:
- Case Number
- Subject  
- Status
- Created Date

**Security**: ✅ Agents can only see cases assigned to them

### Setup Requirements:
1. **Standard Case Object** - No additional setup needed
2. **Agent Permission Sets** - Ensure agents have read access to Case object
3. **Case Assignment** - Cases must be assigned to agents to be visible

---

## 2. Credit Scores Related List Setup

### ❌ Status: Needs Configuration

**Object**: Credit_Score__c (Custom Object)
**Relationship**: Customer__c (Lookup to Account)

### Required Custom Object Setup:

#### A. Credit_Score__c Object Fields:
```
Field Name                  | Type      | Description
---------------------------|-----------|----------------------------------
Customer__c                | Lookup    | Lookup to Account (Required)
Total_Score__c             | Number    | Final calculated credit score
Base_Score__c              | Number    | Base score (default 300)
Internal_Fields_Score__c   | Number    | Score from internal fields
External_Billing_Score__c  | Number    | Score from billing data
API_Score__c               | Number    | Score from external API
Score_Status__c            | Text      | Poor/Good/Excellent
Calculation_Date__c        | DateTime  | When score was calculated
Is_Current__c              | Checkbox  | Is this the current score
Missing_Fields__c          | Text      | List of missing fields
```

#### B. Object Relationships:
```xml
<!-- In Credit_Score__c.object-meta.xml -->
<fields>
    <fullName>Customer__c</fullName>
    <label>Customer</label>
    <referenceTo>Account</referenceTo>
    <relationshipLabel>Credit Scores</relationshipLabel>
    <relationshipName>Credit_Scores</relationshipName>
    <required>true</required>
    <type>Lookup</type>
</fields>
```

#### C. Required Apex Method:
```apex
// Add to AgentService.cls
@AuraEnabled(cacheable=true)
public static List<Credit_Score__c> getCreditScoreHistory(Id accountId, Integer limitRecords) {
    if (accountId == null) {
        throw new AuraHandledException('Account ID is required');
    }
    
    if (limitRecords == null || limitRecords <= 0) {
        limitRecords = 10;
    }
    
    return [
        SELECT Id, Total_Score__c, Score_Status__c, Calculation_Date__c,
               Base_Score__c, Internal_Fields_Score__c, External_Billing_Score__c,
               API_Score__c, Is_Current__c, Missing_Fields__c
        FROM Credit_Score__c
        WHERE Customer__c = :accountId
        ORDER BY Calculation_Date__c DESC
        LIMIT :limitRecords
    ];
}
```

### Setup Steps:

1. **Create Custom Object**: Credit_Score__c with fields listed above
2. **Set Object Permissions**: Grant read access to agent profiles/permission sets
3. **Create Sample Data**: Add Credit_Score__c records linked to Account records
4. **Update Component**: The component already calls this method, just needs the Apex method

---

## 3. Billing Records Related List Setup

### ✅ Status: Already Implemented

**Object**: Billing_Record__c (Custom Object)
**Relationship**: Customer__c (Lookup to Account)

**Apex Method**: `AgentService.getRecentBillingRecords()`
```apex
@AuraEnabled(cacheable=true)
public static List<Billing_Record__c> getRecentBillingRecords(Id accountId, Integer limitRecords) {
    // Returns billing records for the customer
    WHERE Customer__c = :accountId
}
```

**Fields Displayed**:
- Billing ID
- Due Date
- Payment Date  
- Payment Status (On Time/Late)

### Required Custom Object Setup:

#### A. Billing_Record__c Object Fields:
```
Field Name              | Type      | Description
-----------------------|-----------|----------------------------------
Customer__c            | Lookup    | Lookup to Account (Required)
Billing_Id__c          | Text      | External billing system ID
Bill_Due_Date__c       | Date      | When payment is due
Bill_Payment_Date__c   | Date      | When payment was made
Is_Paid_On_Time__c     | Formula   | TRUE if paid before due date
Bill_Amount__c         | Currency  | Amount of the bill
Payment_Status__c      | Text      | Payment status description
```

#### B. Formula Field for Is_Paid_On_Time__c:
```
IF(
    AND(
        NOT(ISBLANK(Bill_Payment_Date__c)),
        NOT(ISBLANK(Bill_Due_Date__c))
    ),
    Bill_Payment_Date__c <= Bill_Due_Date__c,
    FALSE
)
```

### Setup Requirements:
1. **Custom Object**: Billing_Record__c with fields listed above
2. **Agent Permissions**: Read access to Billing_Record__c object
3. **Sample Data**: Billing records linked to Account records

---

## Component Integration

### Current Component Structure:

The customerDetailView component already includes:

1. **JavaScript Methods**:
   - `loadRecentCases()` ✅
   - `loadRecentCreditRequests()` ❌ (Should be loadCreditScoreHistory)
   - `loadRecentBillingRecords()` ✅

2. **HTML Templates**:
   - Cases table ✅
   - Credit Score Requests table ❌ (Should be Credit Score History)
   - Billing Records table ✅

### Required Updates:

#### 1. Update JavaScript (customerDetailView.js):
```javascript
// Replace loadRecentCreditRequests with:
loadCreditScoreHistory(accountId) {
    this.requestsLoading = true;
    getCreditScoreHistory({ accountId, limitRecords: 5 })
        .then(result => {
            this.creditScoreHistory = result.map(score => ({
                ...score,
                formattedDate: new Date(score.Calculation_Date__c).toLocaleDateString(),
                statusClass: this.getScoreStatusClass(score.Score_Status__c)
            }));
        })
        .catch(error => {
            console.error('Error loading credit score history:', error);
            this.creditScoreHistory = [];
        })
        .finally(() => {
            this.requestsLoading = false;
        });
}
```

#### 2. Update HTML Template:
```html
<!-- Replace Credit Score Requests section with: -->
<div class="slds-col slds-size_1-of-1 slds-medium-size_1-of-2">
    <div class="slds-card">
        <div class="slds-card__header">
            <h2 class="slds-card__header-title">
                <lightning-icon icon-name="utility:chart" size="small" class="slds-m-right_x-small"></lightning-icon>
                Credit Score History
            </h2>
            <div class="slds-no-flex">
                <lightning-button 
                    label="View All" 
                    onclick={handleViewCreditHistory}
                    variant="neutral"
                    size="small">
                </lightning-button>
            </div>
        </div>
        <div class="slds-card__body slds-card__body_inner">
            <template if:true={creditScoreHistory}>
                <template if:true={creditScoreHistory.length}>
                    <table class="slds-table slds-table_cell-buffer slds-table_bordered slds-table_striped">
                        <thead>
                            <tr class="slds-line-height_reset">
                                <th scope="col">Date</th>
                                <th scope="col">Score</th>
                                <th scope="col">Status</th>
                                <th scope="col">Change</th>
                            </tr>
                        </thead>
                        <tbody>
                            <template for:each={creditScoreHistory} for:item="score">
                                <tr key={score.Id}>
                                    <td>{score.formattedDate}</td>
                                    <td><strong>{score.Total_Score__c}</strong></td>
                                    <td>
                                        <span class={score.statusClass}>{score.Score_Status__c}</span>
                                    </td>
                                    <td>
                                        <!-- Score change calculation -->
                                    </td>
                                </tr>
                            </template>
                        </tbody>
                    </table>
                </template>
                <template if:false={creditScoreHistory.length}>
                    <div class="slds-text-align_center slds-p-around_medium">
                        <lightning-icon icon-name="utility:info" size="small" class="slds-m-right_x-small"></lightning-icon>
                        No credit score history found.
                    </div>
                </template>
            </template>
        </div>
    </div>
</div>
```

---

## Sample Data Creation

### 1. Account Records (Person Accounts):
```apex
// Create test person accounts
List<Account> accounts = new List<Account>();
for(Integer i = 1; i <= 5; i++) {
    accounts.add(new Account(
        FirstName = 'Test',
        LastName = 'Customer ' + i,
        PersonEmail = 'customer' + i + '@test.com',
        Phone = '555-000-000' + i,
        Age__c = 25 + i,
        External_Customer_ID__c = 'CUST-' + String.valueOf(i).leftPad(4, '0')
    ));
}
insert accounts;
```

### 2. Credit Score Records:
```apex
// Create credit score history
List<Credit_Score__c> scores = new List<Credit_Score__c>();
for(Account acc : accounts) {
    for(Integer i = 0; i < 3; i++) {
        scores.add(new Credit_Score__c(
            Customer__c = acc.Id,
            Total_Score__c = 300 + (Math.random() * 450).intValue(),
            Base_Score__c = 300,
            Internal_Fields_Score__c = (Math.random() * 150).intValue(),
            External_Billing_Score__c = (Math.random() * 150).intValue(),
            API_Score__c = (Math.random() * 150).intValue(),
            Calculation_Date__c = DateTime.now().addDays(-i * 30),
            Is_Current__c = (i == 0)
        ));
    }
}
insert scores;

// Update Score_Status__c based on Total_Score__c
for(Credit_Score__c score : scores) {
    if(score.Total_Score__c >= 600) {
        score.Score_Status__c = 'Excellent';
    } else if(score.Total_Score__c >= 450) {
        score.Score_Status__c = 'Good';
    } else {
        score.Score_Status__c = 'Poor';
    }
}
update scores;
```

### 3. Billing Records:
```apex
// Create billing records
List<Billing_Record__c> billings = new List<Billing_Record__c>();
for(Account acc : accounts) {
    for(Integer i = 1; i <= 6; i++) {
        Date dueDate = Date.today().addDays(-30 * i);
        Date paymentDate = Math.random() > 0.3 ? dueDate.addDays(-2) : dueDate.addDays(5);
        
        billings.add(new Billing_Record__c(
            Customer__c = acc.Id,
            Billing_Id__c = 'BILL-' + acc.External_Customer_ID__c + '-' + String.valueOf(i).leftPad(3, '0'),
            Bill_Due_Date__c = dueDate,
            Bill_Payment_Date__c = paymentDate,
            Bill_Amount__c = 100 + (Math.random() * 500)
        ));
    }
}
insert billings;
```

### 4. Case Records:
```apex
// Create cases assigned to current user
List<Case> cases = new List<Case>();
for(Account acc : accounts) {
    cases.add(new Case(
        AccountId = acc.Id,
        Subject = 'Credit Score Inquiry - ' + acc.Name,
        Description = 'Customer inquiry about credit score calculation',
        Status = 'New',
        Priority = 'Medium',
        Origin = 'Phone',
        OwnerId = UserInfo.getUserId()
    ));
}
insert cases;
```

---

## Permission Sets Configuration

### Agent Permission Set Requirements:

```xml
<!-- DigiCredit_Agent_Access.permissionset-meta.xml -->
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <object>Credit_Score__c</object>
    </objectPermissions>
    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <object>Billing_Record__c</object>
    </objectPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Credit_Score__c.Customer__c</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Credit_Score__c.Total_Score__c</field>
        <readable>true</readable>
    </fieldPermissions>
    <!-- Add all other fields... -->
</PermissionSet>
```

---

## Deployment Checklist

### ✅ Pre-Deployment:
1. [ ] Create Credit_Score__c custom object with all required fields
2. [ ] Create Billing_Record__c custom object with all required fields  
3. [ ] Set up proper lookup relationships to Account
4. [ ] Configure field-level security
5. [ ] Add getCreditScoreHistory method to AgentService
6. [ ] Update permission sets for agent access

### ✅ Post-Deployment:
1. [ ] Create sample data for testing
2. [ ] Assign permission sets to agent users
3. [ ] Test component functionality
4. [ ] Verify security restrictions work correctly

### ✅ Testing Scenarios:
1. [ ] Agent can see all customer information
2. [ ] Agent can only see cases assigned to them
3. [ ] Credit score history displays correctly
4. [ ] Billing records show proper payment status
5. [ ] Related list navigation works
6. [ ] Component handles empty data gracefully

---

## Troubleshooting

### Common Issues:

1. **"No cases found"**: Ensure cases are assigned to the current agent user
2. **"Credit score history not loading"**: Verify Credit_Score__c object exists and has data
3. **"Permission denied"**: Check agent permission sets include required object access
4. **"Relationship not found"**: Verify lookup fields are properly configured

### Debug Steps:
1. Check browser console for JavaScript errors
2. Verify Apex method execution in Developer Console
3. Test SOQL queries directly in Query Editor
4. Confirm object and field permissions in Setup

This setup guide provides everything needed to configure the three related lists properly. The component code is already structured to support these related lists - it just needs the proper data model and Apex methods in place.
