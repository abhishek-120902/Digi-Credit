import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getBillingHistory from '@salesforce/apex/BillingDataIntegrationService.getBillingRecords';
import getCreditScoreRequests from '@salesforce/apex/CreditScoreCalculationService.getCreditScoreRequests';
import createCreditScoreRequest from '@salesforce/apex/CreditScoreCalculationService.createCreditScoreRequest';

// Get current user ID
import USER_ID from '@salesforce/user/Id';

// Account fields
import ACCOUNT_ID_FIELD from '@salesforce/schema/Account.Id';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import ACCOUNT_PHONE_FIELD from '@salesforce/schema/Account.Phone';
import ACCOUNT_EMAIL_FIELD from '@salesforce/schema/Account.Email__c';
import ACCOUNT_AGE_FIELD from '@salesforce/schema/Account.Age__c';
import ACCOUNT_CUSTOM_FIELD from '@salesforce/schema/Account.Custom_Field__c';
import ACCOUNT_EXTERNAL_ID_FIELD from '@salesforce/schema/Account.External_Customer_ID__c';
import ACCOUNT_CURRENT_SCORE_FIELD from '@salesforce/schema/Account.Current_Credit_Score__c';
import ACCOUNT_LAST_CALCULATION_FIELD from '@salesforce/schema/Account.Last_Score_Calculation__c';

const ACCOUNT_FIELDS = [
    ACCOUNT_ID_FIELD,
    ACCOUNT_NAME_FIELD,
    ACCOUNT_PHONE_FIELD,
    ACCOUNT_EMAIL_FIELD,
    ACCOUNT_AGE_FIELD,
    ACCOUNT_CUSTOM_FIELD,
    ACCOUNT_EXTERNAL_ID_FIELD,
    ACCOUNT_CURRENT_SCORE_FIELD,
    ACCOUNT_LAST_CALCULATION_FIELD
];

const USER_FIELDS = [
    'User.Id',
    'User.ContactId',
    'User.Contact.AccountId'
];

export default class CustomerDashboard extends NavigationMixin(LightningElement) {
    @api recordId; // Account ID
    @api dashboardTitle = 'My Dashboard';
    
    @track isLoading = false;
    @track isRequestingScore = false;
    @track activeTab = 'overview';
    @track billingHistory = [];
    @track creditScoreRequests = [];
    @track error;
    @track userAccountId;
    
    wiredUserResult;
    wiredAccountResult;
    wiredBillingResult;
    wiredRequestsResult;

    // Get the current user's Account ID using wire method (requires Permission Set)
    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    wiredUser(result) {
        this.wiredUserResult = result;
        console.log('User wire result:', JSON.stringify(result, null, 2));
        
        if (result.data) {
            console.log('User data fields:', result.data.fields);
            
            // Get Account ID from User's Contact
            if (result.data.fields.ContactId && result.data.fields.ContactId.value) {
                const contactId = result.data.fields.ContactId.value;
                console.log('Contact ID found:', contactId);
                
                // Try different ways to access the Account ID
                if (result.data.fields['User.Contact.AccountId']) {
                    this.userAccountId = result.data.fields['User.Contact.AccountId'].value;
                    console.log('Account ID from User.Contact.AccountId:', this.userAccountId);
                } else if (result.data.fields.Contact && result.data.fields.Contact.value) {
                    console.log('Contact data:', result.data.fields.Contact.value);
                    if (result.data.fields.Contact.value.fields && 
                        result.data.fields.Contact.value.fields.AccountId) {
                        this.userAccountId = result.data.fields.Contact.value.fields.AccountId.value;
                        console.log('Account ID from nested Contact:', this.userAccountId);
                    }
                }
            } else {
                console.log('No ContactId found for user');
            }
        } else if (result.error) {
            console.error('Error fetching user data:', result.error);
            this.showErrorToast('Error', 'Error loading user data. Please ensure you have the required permissions.', 'error');
            this.isLoading = false;
        }
    }

    // Wire account data
    @wire(getRecord, { recordId: '$effectiveRecordId', fields: ACCOUNT_FIELDS })
    wiredAccount(result) {
        this.wiredAccountResult = result;
        if (result.error) {
            this.error = result.error;
            this.showErrorToast('Error loading account data', result.error.body?.message || result.error.message);
        }
    }

    // Wire billing history
    @wire(getBillingHistory, { accountId: '$effectiveRecordId' })
    wiredBillingHistory(result) {
        this.wiredBillingResult = result;
        if (result.data) {
            this.billingHistory = result.data.map(record => ({
                ...record,
                formattedDueDate: this.formatDate(record.Bill_Due_Date__c),
                formattedPaymentDate: this.formatDate(record.Bill_Payment_Date__c),
                statusClass: this.getBillingStatusClass(record.Payment_Status__c),
                formattedAmount: this.formatCurrency(record.Bill_Amount__c)
            }));
        } else if (result.error) {
            this.showErrorToast('Error loading billing history', result.error.body?.message || result.error.message);
        }
    }

    // Wire credit score requests
    @wire(getCreditScoreRequests, { accountId: '$effectiveRecordId' })
    wiredCreditScoreRequests(result) {
        this.wiredRequestsResult = result;
        if (result.data) {
            this.creditScoreRequests = result.data.map(request => ({
                ...request,
                formattedRequestDate: this.formatDateTime(request.Requested_Date__c),
                formattedCompletedDate: this.formatDateTime(request.Completed_Date__c),
                statusClass: this.getRequestStatusClass(request.Request_Status__c)
            }));
        } else if (result.error) {
            this.showErrorToast('Error loading credit score requests', result.error.body?.message || result.error.message);
        }
    }

    // Use recordId if provided, otherwise use current user's Account ID
    get effectiveRecordId() {
        return this.recordId || this.userAccountId;
    }

    // Getters for account data
    get account() {
        return this.wiredAccountResult?.data;
    }

    get accountName() {
        return getFieldValue(this.account, ACCOUNT_NAME_FIELD);
    }

    get accountPhone() {
        return getFieldValue(this.account, ACCOUNT_PHONE_FIELD);
    }

    get accountEmail() {
        return getFieldValue(this.account, ACCOUNT_EMAIL_FIELD);
    }

    get accountAge() {
        return getFieldValue(this.account, ACCOUNT_AGE_FIELD);
    }

    get customField() {
        return getFieldValue(this.account, ACCOUNT_CUSTOM_FIELD);
    }

    get currentScore() {
        return getFieldValue(this.account, ACCOUNT_CURRENT_SCORE_FIELD);
    }

    get lastCalculationDate() {
        const date = getFieldValue(this.account, ACCOUNT_LAST_CALCULATION_FIELD);
        return date ? this.formatDateTime(date) : 'Never calculated';
    }

    get profileCompletionPercentage() {
        if (!this.account) return 0;
        
        const requiredFields = [
            ACCOUNT_NAME_FIELD,
            ACCOUNT_PHONE_FIELD,
            ACCOUNT_EMAIL_FIELD,
            ACCOUNT_AGE_FIELD,
            ACCOUNT_CUSTOM_FIELD
        ];
        
        const completedFields = requiredFields.filter(field => {
            const value = getFieldValue(this.account, field);
            return value != null && value !== '';
        }).length;
        
        return Math.round((completedFields / requiredFields.length) * 100);
    }

    get profileCompletionClass() {
        const percentage = this.profileCompletionPercentage;
        if (percentage >= 80) return 'slds-progress-bar__value progress-success';
        if (percentage >= 50) return 'slds-progress-bar__value progress-warning';
        return 'slds-progress-bar__value progress-error';
    }

    get hasCurrentScore() {
        return this.currentScore != null && this.currentScore > 0;
    }

    get hasBillingHistory() {
        return this.billingHistory && this.billingHistory.length > 0;
    }

    get hasRequests() {
        return this.creditScoreRequests && this.creditScoreRequests.length > 0;
    }

    get tabClasses() {
        return {
            overview: `slds-tabs_default__item ${this.activeTab === 'overview' ? 'slds-is-active' : ''}`,
            billing: `slds-tabs_default__item ${this.activeTab === 'billing' ? 'slds-is-active' : ''}`,
            requests: `slds-tabs_default__item ${this.activeTab === 'requests' ? 'slds-is-active' : ''}`
        };
    }

    get isOverviewTab() {
        return this.activeTab === 'overview';
    }

    get isBillingTab() {
        return this.activeTab === 'billing';
    }

    get isRequestsTab() {
        return this.activeTab === 'requests';
    }


    // Tab navigation handlers
    handleTabClick(event) {
        this.activeTab = event.target.dataset.tab;
    }


    // Credit score request handler
    async handleRequestCreditScore() {
        this.isRequestingScore = true;
        try {
            await createCreditScoreRequest({ 
                accountId: this.effectiveRecordId,
                requestChannel: 'Community'
            });
            
            // Refresh requests data
            await refreshApex(this.wiredRequestsResult);
            
            this.showSuccessToast('Request Submitted', 'Your credit score request has been submitted and will be processed shortly.');
        } catch (error) {
            this.showErrorToast('Request Failed', error.body?.message || error.message);
        } finally {
            this.isRequestingScore = false;
        }
    }

    // Navigation handlers
    handleViewCreditScore() {
        // Navigate to credit score page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Credit_Score__c'
            }
        });
    }

    handleNavigateToProfile() {
        // Navigate to profile page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'My_Profile__c'
            }
        });
    }

    handleNavigateToRequestScore() {
        // Navigate to request score page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Request_Score__c'
            }
        });
    }

    handleNavigateToSupport() {
        // Navigate to support page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Support__c'
            }
        });
    }

    handleViewFullProfile() {
        // Navigate to full profile page (custom profile display)
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'My_Profile__c'
            }
        });
    }

    handleViewBillingDetails(event) {
        const billingId = event.target.dataset.id;
        // Navigate to billing record detail
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: billingId,
                objectApiName: 'Billing_Record__c',
                actionName: 'view'
            }
        });
    }

    // Utility methods
    formatDate(dateValue) {
        if (!dateValue) return '';
        return new Date(dateValue).toLocaleDateString();
    }

    formatDateTime(dateTimeValue) {
        if (!dateTimeValue) return '';
        return new Date(dateTimeValue).toLocaleString();
    }

    formatCurrency(amount) {
        if (!amount) return '$0.00';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount);
    }

    getBillingStatusClass(status) {
        switch (status) {
            case 'On Time':
                return 'slds-badge slds-theme_success';
            case 'Late':
                return 'slds-badge slds-theme_error';
            case 'Unpaid':
                return 'slds-badge slds-theme_warning';
            default:
                return 'slds-badge';
        }
    }

    getRequestStatusClass(status) {
        switch (status) {
            case 'Completed':
                return 'slds-badge slds-theme_success';
            case 'Processing':
                return 'slds-badge slds-theme_info';
            case 'Failed':
                return 'slds-badge slds-theme_error';
            default:
                return 'slds-badge slds-theme_warning';
        }
    }

    // Toast message utilities
    showSuccessToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'success'
        }));
    }

    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error'
        }));
    }

    showInfoToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'info'
        }));
    }
}