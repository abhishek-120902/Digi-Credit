# CASE ASSIGNMENT RULES SETUP - UNIVERSAL CONTAINERS CREDIT REPORTING AGENCY

## Overview
This guide provides complete step-by-step instructions for setting up Case Assignment Rules for Universal Containers' Credit Reporting Agency system. The setup ensures proper case routing based on customer type, case category, agent specialization, and business requirements.

## Prerequisites
- Salesforce org with Case Management enabled
- System Administrator access
- Understanding of Universal Containers business processes
- Existing User roles: Customer, Agent, Executive

---

## PHASE 1: FOUNDATION SETUP

### Step 1: Create Custom Fields on Case Object

#### 1.1 Customer Tier Field
**Purpose**: Categorize customers for priority-based assignment

**Field Details**:
- **Field Label**: Customer Tier
- **Field Name**: Customer_Tier__c
- **Data Type**: Picklist
- **Values**:
  - Premium (High priority, specialized agents)
  - Standard (Normal priority, general agents)
  - Basic (Standard priority, any available agent)
- **Default Value**: Standard
- **Required**: Yes

**Setup Steps**:
1. Navigate to Setup → Object Manager → Case
2. Click Fields & Relationships → New
3. Select Picklist and click Next
4. Enter field details above
5. Add picklist values as specified
6. Set field-level security for all profiles
7. Add to relevant page layouts

#### 1.2 Case Category Field
**Purpose**: Categorize cases for specialized routing

**Field Details**:
- **Field Label**: Case Category
- **Field Name**: Case_Category__c
- **Data Type**: Picklist
- **Values**:
  - Credit Score Inquiry
  - Billing Dispute
  - Technical Support
  - Account Management
  - Data Correction
  - General Inquiry
- **Required**: Yes

#### 1.3 Agent Specialization Required Field
**Purpose**: Indicate if case needs specialized agent

**Field Details**:
- **Field Label**: Specialization Required
- **Field Name**: Specialization_Required__c
- **Data Type**: Picklist
- **Values**:
  - Credit Analysis
  - Billing Expert
  - Technical Support
  - Senior Agent
  - None
- **Default Value**: None

#### 1.4 Customer Region Field
**Purpose**: Geographic routing for regional support

**Field Details**:
- **Field Label**: Customer Region
- **Field Name**: Customer_Region__c
- **Data Type**: Picklist
- **Values**:
  - North America
  - Europe
  - Asia Pacific
  - Latin America
  - Other
- **Required**: Yes

#### 1.5 Business Hours Field
**Purpose**: Track business hours for SLA calculation

**Field Details**:
- **Field Label**: Business Hours
- **Field Name**: Business_Hours__c
- **Data Type**: Lookup (BusinessHours)
- **Required**: No

### Step 2: Create User Custom Fields for Agent Management

#### 2.1 Agent Specialization Field on User Object
**Purpose**: Define agent expertise areas

**Field Details**:
- **Field Label**: Agent Specialization
- **Field Name**: Agent_Specialization__c
- **Data Type**: Multi-Select Picklist
- **Values**:
  - Credit Analysis
  - Billing Expert
  - Technical Support
  - Senior Agent
  - General Support
- **Required**: No (only for Agent users)

#### 2.2 Agent Region Field on User Object
**Purpose**: Define agent's supported regions

**Field Details**:
- **Field Label**: Supported Regions
- **Field Name**: Supported_Regions__c
- **Data Type**: Multi-Select Picklist
- **Values**:
  - North America
  - Europe
  - Asia Pacific
  - Latin America
  - Global
- **Required**: No (only for Agent users)

#### 2.3 Agent Capacity Field on User Object
**Purpose**: Track agent workload capacity

**Field Details**:
- **Field Label**: Max Case Capacity
- **Field Name**: Max_Case_Capacity__c
- **Data Type**: Number(3,0)
- **Default Value**: 20
- **Required**: No

---

## PHASE 2: QUEUE SETUP

### Step 3: Create Case Queues

#### 3.1 Specialized Agent Queues

**Queue 1: Credit Analysis Queue**
- **Queue Name**: Credit Analysis Team
- **Developer Name**: Credit_Analysis_Team
- **Email**: credit-analysis@universalcontainers.com
- **Members**: Users with "Credit Analysis" specialization
- **Supported Objects**: Case

**Queue 2: Billing Support Queue**
- **Queue Name**: Billing Support Team
- **Developer Name**: Billing_Support_Team
- **Email**: billing-support@universalcontainers.com
- **Members**: Users with "Billing Expert" specialization
- **Supported Objects**: Case

**Queue 3: Technical Support Queue**
- **Queue Name**: Technical Support Team
- **Developer Name**: Technical_Support_Team
- **Email**: tech-support@universalcontainers.com
- **Members**: Users with "Technical Support" specialization
- **Supported Objects**: Case

**Queue 4: Senior Agent Queue**
- **Queue Name**: Senior Agent Team
- **Developer Name**: Senior_Agent_Team
- **Email**: senior-agents@universalcontainers.com
- **Members**: Users with "Senior Agent" specialization
- **Supported Objects**: Case

#### 3.2 Regional Queues

**Queue 5: North America Support**
- **Queue Name**: North America Support
- **Developer Name**: North_America_Support
- **Email**: na-support@universalcontainers.com
- **Members**: Users supporting North America region
- **Supported Objects**: Case

**Queue 6: Europe Support**
- **Queue Name**: Europe Support
- **Developer Name**: Europe_Support
- **Email**: eu-support@universalcontainers.com
- **Members**: Users supporting Europe region
- **Supported Objects**: Case

#### 3.3 Priority Queues

**Queue 7: Premium Customer Queue**
- **Queue Name**: Premium Customer Support
- **Developer Name**: Premium_Customer_Support
- **Email**: premium-support@universalcontainers.com
- **Members**: Senior agents and specialized staff
- **Supported Objects**: Case

**Queue 8: Escalation Queue**
- **Queue Name**: Escalation Team
- **Developer Name**: Escalation_Team
- **Email**: escalation@universalcontainers.com
- **Members**: Senior agents and managers
- **Supported Objects**: Case

### Queue Setup Steps:
1. Navigate to Setup → Users → Queues
2. Click New for each queue
3. Enter queue details as specified above
4. Add appropriate queue members based on user specializations
5. Set queue email addresses for notifications

---

## PHASE 3: ASSIGNMENT RULES CONFIGURATION

### Step 4: Create Case Assignment Rules

#### 4.1 Main Assignment Rule: "Universal Containers Case Routing"

**Rule Activation**: Set as Active

#### 4.2 Assignment Rule Entries (Order Matters!)

**Entry 1: Premium Customer - Credit Analysis**
- **Rule Name**: Premium Credit Analysis
- **Sort Order**: 1
- **Criteria**:
  - Customer_Tier__c EQUALS Premium
  - AND Case_Category__c EQUALS Credit Score Inquiry
- **Assigned To**: Credit Analysis Team (Queue)
- **Email Template**: Premium Customer Assignment Notification

**Entry 2: Premium Customer - Billing Issues**
- **Rule Name**: Premium Billing Support
- **Sort Order**: 2
- **Criteria**:
  - Customer_Tier__c EQUALS Premium
  - AND Case_Category__c EQUALS Billing Dispute
- **Assigned To**: Billing Support Team (Queue)
- **Email Template**: Premium Customer Assignment Notification

**Entry 3: Premium Customer - Technical Issues**
- **Rule Name**: Premium Technical Support
- **Sort Order**: 3
- **Criteria**:
  - Customer_Tier__c EQUALS Premium
  - AND Case_Category__c EQUALS Technical Support
- **Assigned To**: Technical Support Team (Queue)
- **Email Template**: Premium Customer Assignment Notification

**Entry 4: Premium Customer - General**
- **Rule Name**: Premium General Support
- **Sort Order**: 4
- **Criteria**:
  - Customer_Tier__c EQUALS Premium
- **Assigned To**: Premium Customer Support (Queue)
- **Email Template**: Premium Customer Assignment Notification

**Entry 5: Credit Score Inquiries**
- **Rule Name**: Credit Analysis Routing
- **Sort Order**: 5
- **Criteria**:
  - Case_Category__c EQUALS Credit Score Inquiry
- **Assigned To**: Credit Analysis Team (Queue)
- **Email Template**: Standard Assignment Notification

**Entry 6: Billing Disputes**
- **Rule Name**: Billing Support Routing
- **Sort Order**: 6
- **Criteria**:
  - Case_Category__c EQUALS Billing Dispute
- **Assigned To**: Billing Support Team (Queue)
- **Email Template**: Standard Assignment Notification

**Entry 7: Technical Support**
- **Rule Name**: Technical Support Routing
- **Sort Order**: 7
- **Criteria**:
  - Case_Category__c EQUALS Technical Support
- **Assigned To**: Technical Support Team (Queue)
- **Email Template**: Standard Assignment Notification

**Entry 8: High Priority Cases**
- **Rule Name**: High Priority Routing
- **Sort Order**: 8
- **Criteria**:
  - Priority EQUALS High
- **Assigned To**: Senior Agent Team (Queue)
- **Email Template**: High Priority Assignment Notification

**Entry 9: Regional Routing - North America**
- **Rule Name**: North America Regional
- **Sort Order**: 9
- **Criteria**:
  - Customer_Region__c EQUALS North America
  - AND Priority NOT EQUAL TO High
- **Assigned To**: North America Support (Queue)
- **Email Template**: Regional Assignment Notification

**Entry 10: Regional Routing - Europe**
- **Rule Name**: Europe Regional
- **Sort Order**: 10
- **Criteria**:
  - Customer_Region__c EQUALS Europe
  - AND Priority NOT EQUAL TO High
- **Assigned To**: Europe Support (Queue)
- **Email Template**: Regional Assignment Notification

**Entry 11: Default Assignment**
- **Rule Name**: Default Case Assignment
- **Sort Order**: 11
- **Criteria**: (No criteria - catches all remaining cases)
- **Assigned To**: Senior Agent Team (Queue)
- **Email Template**: Default Assignment Notification

### Assignment Rule Setup Steps:
1. Navigate to Setup → Case Management → Assignment Rules
2. Click New to create "Universal Containers Case Routing"
3. Save and then add Rule Entries in the order specified above
4. For each entry:
   - Click New Rule Entry
   - Enter criteria using Advanced Formula (when needed)
   - Select appropriate queue for assignment
   - Choose email template for notifications
5. Activate the assignment rule

---

## PHASE 4: ESCALATION RULES

### Step 5: Create Escalation Rules

#### 5.1 Main Escalation Rule: "Universal Containers Case Escalation"

**Rule Activation**: Set as Active

#### 5.2 Escalation Rule Entries

**Entry 1: Premium Customer Escalation**
- **Rule Name**: Premium Customer SLA
- **Criteria**:
  - Customer_Tier__c EQUALS Premium
- **Escalation Actions**:
  - **Age Over (Hours)**: 2
  - **Escalate To**: Escalation Team (Queue)
  - **Email Template**: Premium Escalation Notification
  - **Additional Actions**: Send email to case owner and manager

**Entry 2: High Priority Escalation**
- **Rule Name**: High Priority SLA
- **Criteria**:
  - Priority EQUALS High
- **Escalation Actions**:
  - **Age Over (Hours)**: 4
  - **Escalate To**: Escalation Team (Queue)
  - **Email Template**: High Priority Escalation Notification

**Entry 3: Standard Escalation**
- **Rule Name**: Standard Case SLA
- **Criteria**: (No criteria - applies to all cases)
- **Escalation Actions**:
  - **Age Over (Hours)**: 24
  - **Escalate To**: Senior Agent Team (Queue)
  - **Email Template**: Standard Escalation Notification

### Escalation Rule Setup Steps:
1. Navigate to Setup → Case Management → Escalation Rules
2. Click New to create "Universal Containers Case Escalation"
3. Add Rule Entries as specified above
4. Configure escalation actions for each entry
5. Activate the escalation rule

---

## PHASE 5: EMAIL TEMPLATES

### Step 6: Create Email Templates for Notifications

#### 6.1 Premium Customer Assignment Notification
```html
Subject: [PREMIUM] Case {!Case.CaseNumber} Assigned - {!Case.Subject}

Dear {!Case.Owner.FirstName},

A premium customer case has been assigned to you:

Case Number: {!Case.CaseNumber}
Customer: {!Case.Account.Name}
Subject: {!Case.Subject}
Priority: {!Case.Priority}
Category: {!Case.Case_Category__c}

Please respond within 2 hours as per our Premium SLA.

Case Link: {!Case.Link}

Best regards,
Universal Containers Support Team
```

#### 6.2 Standard Assignment Notification
```html
Subject: Case {!Case.CaseNumber} Assigned - {!Case.Subject}

Dear {!Case.Owner.FirstName},

A new case has been assigned to your queue:

Case Number: {!Case.CaseNumber}
Customer: {!Case.Account.Name}
Subject: {!Case.Subject}
Priority: {!Case.Priority}
Category: {!Case.Case_Category__c}

Please review and respond according to our standard SLA.

Case Link: {!Case.Link}

Best regards,
Universal Containers Support Team
```

#### 6.3 Escalation Notification Templates
Create similar templates for escalation notifications with appropriate urgency messaging.

---

## PHASE 6: BUSINESS HOURS AND ENTITLEMENTS

### Step 7: Configure Business Hours

#### 7.1 Create Business Hours Records

**Business Hours 1: North America Support Hours**
- **Name**: North America Business Hours
- **Time Zone**: America/New_York
- **Hours**: Monday-Friday, 8:00 AM - 8:00 PM EST
- **Holidays**: Include major US holidays

**Business Hours 2: Europe Support Hours**
- **Name**: Europe Business Hours
- **Time Zone**: Europe/London
- **Hours**: Monday-Friday, 9:00 AM - 6:00 PM GMT
- **Holidays**: Include major European holidays

**Business Hours 3: 24/7 Premium Support**
- **Name**: Premium Support Hours
- **Time Zone**: GMT
- **Hours**: 24/7 coverage
- **Holidays**: No holidays (continuous support)

### Step 8: Create Entitlement Processes

#### 8.1 Premium Customer Entitlement Process
- **Name**: Premium Customer SLA
- **Business Hours**: Premium Support Hours
- **Milestones**:
  - First Response: 2 hours
  - Resolution: 24 hours

#### 8.2 Standard Customer Entitlement Process
- **Name**: Standard Customer SLA
- **Business Hours**: Regional Business Hours
- **Milestones**:
  - First Response: 8 hours
  - Resolution: 72 hours

---

## PHASE 7: AUTOMATION AND WORKFLOWS

### Step 9: Create Process Builder/Flow for Advanced Assignment

#### 9.1 Case Assignment Enhancement Process
**Purpose**: Handle complex assignment logic that assignment rules cannot handle

**Trigger**: When Case is created or updated

**Criteria and Actions**:

1. **Premium Customer with Multiple Specializations**
   - **Criteria**: Customer_Tier__c = Premium AND Case requires multiple specializations
   - **Action**: Assign to Premium Customer Support queue and create task for coordination

2. **Overflow Management**
   - **Criteria**: Queue has more than 50 open cases
   - **Action**: Reassign to overflow queue and notify management

3. **After-Hours Assignment**
   - **Criteria**: Case created outside business hours
   - **Action**: Assign to on-call queue and set appropriate priority

#### 9.2 Agent Capacity Management Flow
**Purpose**: Prevent agent overload by checking capacity before assignment

**Logic**:
1. Check agent's current case count
2. If at capacity, route to queue instead of individual
3. Send notification to management if all agents at capacity

---

## PHASE 8: TESTING AND VALIDATION

### Step 10: Test Case Assignment Rules

#### 10.1 Test Scenarios

**Test 1: Premium Customer Credit Inquiry**
- Create case with Customer_Tier__c = Premium, Case_Category__c = Credit Score Inquiry
- **Expected**: Assigned to Credit Analysis Team
- **Verify**: Assignment happens within 1 minute, email sent

**Test 2: Standard Billing Dispute**
- Create case with Customer_Tier__c = Standard, Case_Category__c = Billing Dispute
- **Expected**: Assigned to Billing Support Team
- **Verify**: Proper queue assignment

**Test 3: High Priority Technical Issue**
- Create case with Priority = High, Case_Category__c = Technical Support
- **Expected**: Assigned to Senior Agent Team (due to high priority override)
- **Verify**: High priority takes precedence

**Test 4: Regional Assignment**
- Create case with Customer_Region__c = Europe, no special criteria
- **Expected**: Assigned to Europe Support queue
- **Verify**: Regional routing works

**Test 5: Default Assignment**
- Create case with no matching criteria
- **Expected**: Assigned to Senior Agent Team (default)
- **Verify**: Fallback assignment works

#### 10.2 Escalation Testing

**Test 1: Premium Customer Escalation**
- Create premium customer case and wait 2+ hours
- **Expected**: Case escalates to Escalation Team
- **Verify**: Escalation triggers, notifications sent

**Test 2: Standard Case Escalation**
- Create standard case and wait 24+ hours
- **Expected**: Case escalates to Senior Agent Team
- **Verify**: Standard escalation works

### Step 11: Performance Monitoring

#### 11.1 Create Reports for Monitoring

**Report 1: Assignment Rule Performance**
- **Type**: Cases Report
- **Filters**: Created Date = Last 30 Days
- **Grouping**: By Owner (Queue vs Individual)
- **Metrics**: Count, Average Assignment Time

**Report 2: Queue Workload Distribution**
- **Type**: Cases Report
- **Filters**: Status != Closed
- **Grouping**: By Owner (Queue)
- **Metrics**: Count by Priority, Age

**Report 3: Escalation Tracking**
- **Type**: Cases Report
- **Filters**: Escalated = True, Created Date = Last 30 Days
- **Grouping**: By Escalation Reason
- **Metrics**: Count, Time to Escalation

#### 11.2 Dashboard Creation

**Dashboard: Case Assignment Performance**
- Queue workload distribution (pie chart)
- Assignment time trends (line chart)
- Escalation rate by customer tier (bar chart)
- Agent capacity utilization (gauge chart)

---

## PHASE 9: MAINTENANCE AND OPTIMIZATION

### Step 12: Ongoing Maintenance Tasks

#### 12.1 Weekly Reviews
- Review queue workload distribution
- Check for assignment rule gaps
- Monitor escalation rates
- Analyze agent capacity utilization

#### 12.2 Monthly Optimizations
- Update assignment criteria based on performance
- Adjust queue membership based on specializations
- Review and update SLA targets
- Optimize escalation thresholds

#### 12.3 Quarterly Assessments
- Full assignment rule review
- Customer satisfaction correlation analysis
- Agent specialization updates
- Business hours adjustments

---

## TROUBLESHOOTING GUIDE

### Common Issues and Solutions

#### Issue 1: Cases Not Being Assigned
**Symptoms**: Cases remain unassigned after creation
**Causes**: 
- Assignment rule not active
- No matching rule criteria
- Queue has no members
**Solutions**:
- Verify assignment rule is active
- Check rule criteria and order
- Ensure queues have active members

#### Issue 2: Wrong Queue Assignment
**Symptoms**: Cases assigned to incorrect queues
**Causes**:
- Rule order incorrect
- Criteria overlap
- Field values not populated
**Solutions**:
- Review rule entry order
- Refine criteria to avoid overlap
- Ensure required fields are populated

#### Issue 3: Escalation Not Triggering
**Symptoms**: Cases not escalating per SLA
**Causes**:
- Escalation rule not active
- Business hours misconfigured
- Entitlement process issues
**Solutions**:
- Activate escalation rules
- Verify business hours setup
- Check entitlement process configuration

#### Issue 4: Email Notifications Not Sent
**Symptoms**: Assignment emails not received
**Causes**:
- Email template issues
- Deliverability problems
- User email preferences
**Solutions**:
- Test email templates
- Check email deliverability settings
- Verify user notification preferences

---

## SECURITY CONSIDERATIONS

### Data Access Controls
- Ensure agents can only see cases assigned to them or their queues
- Implement field-level security for sensitive case data
- Use sharing rules to control case visibility by region/specialization

### Permission Sets
- Create permission sets for different agent roles
- Grant appropriate case management permissions
- Ensure proper queue access permissions

---

## PERFORMANCE OPTIMIZATION

### Best Practices
- Keep assignment rule criteria simple and efficient
- Use indexed fields in rule criteria when possible
- Monitor rule execution time and optimize as needed
- Regularly review and clean up unused queues

### Scalability Considerations
- Plan for growth in case volume
- Consider load balancing across multiple queues
- Implement automated capacity management
- Use asynchronous processing for complex assignments

---

## CONCLUSION

This comprehensive Case Assignment Rules setup ensures that Universal Containers can efficiently route cases to the appropriate agents based on customer tier, case category, specialization requirements, and regional considerations. The system includes proper escalation handling, performance monitoring, and maintenance procedures to ensure optimal operation.

Regular monitoring and optimization of these rules will help maintain high customer satisfaction and efficient agent utilization as the business grows and evolves.

---

## APPENDIX

### A. Field API Names Reference
- Customer_Tier__c
- Case_Category__c
- Specialization_Required__c
- Customer_Region__c
- Business_Hours__c
- Agent_Specialization__c (User)
- Supported_Regions__c (User)
- Max_Case_Capacity__c (User)

### B. Queue Developer Names Reference
- Credit_Analysis_Team
- Billing_Support_Team
- Technical_Support_Team
- Senior_Agent_Team
- North_America_Support
- Europe_Support
- Premium_Customer_Support
- Escalation_Team

### C. Business Hours Names Reference
- North America Business Hours
- Europe Business Hours
- Premium Support Hours

### D. Assignment Rule Names Reference
- Universal Containers Case Routing (Main Assignment Rule)
- Universal Containers Case Escalation (Main Escalation Rule)
