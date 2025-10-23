//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getBillingHistory from '@salesforce/apex/BillingDataIntegrationService.getBillingRecords';
import getCreditScoreRequests from '@salesforce/apex/CreditScoreCalculationService.getCreditScoreRequests';
import createCreditScoreRequest from '@salesforce/apex/CreditScoreCalculationService.createCreditScoreRequest';

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
import ACCOUNT_BILLING_STREET_FIELD from '@salesforce/schema/Account.BillingStreet';
import ACCOUNT_BILLING_CITY_FIELD from '@salesforce/schema/Account.BillingCity';
import ACCOUNT_BILLING_STATE_FIELD from '@salesforce/schema/Account.BillingState';
import ACCOUNT_BILLING_POSTAL_CODE_FIELD from '@salesforce/schema/Account.BillingPostalCode';
import ACCOUNT_BILLING_COUNTRY_FIELD from '@salesforce/schema/Account.BillingCountry';

const ACCOUNT_FIELDS = [
    ACCOUNT_ID_FIELD,
    ACCOUNT_NAME_FIELD,
    ACCOUNT_PHONE_FIELD,
    ACCOUNT_EMAIL_FIELD,
    ACCOUNT_AGE_FIELD,
    ACCOUNT_CUSTOM_FIELD,
    ACCOUNT_EXTERNAL_ID_FIELD,
    ACCOUNT_CURRENT_SCORE_FIELD,
    ACCOUNT_LAST_CALCULATION_FIELD,
    ACCOUNT_BILLING_STREET_FIELD,
    ACCOUNT_BILLING_CITY_FIELD,
    ACCOUNT_BILLING_STATE_FIELD,
    ACCOUNT_BILLING_POSTAL_CODE_FIELD,
    ACCOUNT_BILLING_COUNTRY_FIELD
];

export default class CustomerDashboard extends NavigationMixin(LightningElement) {
    @api recordId; // Account ID
    @api dashboardTitle = 'My Dashboard';
    
    @track isLoading = false;
    @track isEditing = false;
    @track isSaving = false;
    @track isRequestingScore = false;
    @track activeTab = 'overview';
    @track billingHistory = [];
    @track creditScoreRequests = [];
    @track editableAccount = {};
    @track error;

    // Wire account data
    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    wiredAccount(result) {
        this.wiredAccountResult = result;
        if (result.data) {
            this.initializeEditableAccount(result.data);
        } else if (result.error) {
            this.error = result.error;
            this.showErrorToast('Error loading account data', result.error.body?.message || result.error.message);
        }
    }

    // Wire billing history
    @wire(getBillingHistory, { accountId: '$recordId' })
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
    @wire(getCreditScoreRequests, { accountId: '$recordId' })
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

    get billingAddress() {
        const street = getFieldValue(this.account, ACCOUNT_BILLING_STREET_FIELD);
        const city = getFieldValue(this.account, ACCOUNT_BILLING_CITY_FIELD);
        const state = getFieldValue(this.account, ACCOUNT_BILLING_STATE_FIELD);
        const postalCode = getFieldValue(this.account, ACCOUNT_BILLING_POSTAL_CODE_FIELD);
        const country = getFieldValue(this.account, ACCOUNT_BILLING_COUNTRY_FIELD);
        
        const addressParts = [street, city, state, postalCode, country].filter(part => part);
        return addressParts.length > 0 ? addressParts.join(', ') : 'No address provided';
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
            profile: `slds-tabs_default__item ${this.activeTab === 'profile' ? 'slds-is-active' : ''}`,
            billing: `slds-tabs_default__item ${this.activeTab === 'billing' ? 'slds-is-active' : ''}`,
            requests: `slds-tabs_default__item ${this.activeTab === 'requests' ? 'slds-is-active' : ''}`
        };
    }

    get isOverviewTab() {
        return this.activeTab === 'overview';
    }

    get isProfileTab() {
        return this.activeTab === 'profile';
    }

    get isBillingTab() {
        return this.activeTab === 'billing';
    }

    get isRequestsTab() {
        return this.activeTab === 'requests';
    }

    // Initialize editable account data
    initializeEditableAccount(accountData) {
        this.editableAccount = {
            Id: getFieldValue(accountData, ACCOUNT_ID_FIELD),
            Name: getFieldValue(accountData, ACCOUNT_NAME_FIELD),
            Phone: getFieldValue(accountData, ACCOUNT_PHONE_FIELD),
            Email__c: getFieldValue(accountData, ACCOUNT_EMAIL_FIELD),
            Age__c: getFieldValue(accountData, ACCOUNT_AGE_FIELD),
            Custom_Field__c: getFieldValue(accountData, ACCOUNT_CUSTOM_FIELD),
            BillingStreet: getFieldValue(accountData, ACCOUNT_BILLING_STREET_FIELD),
            BillingCity: getFieldValue(accountData, ACCOUNT_BILLING_CITY_FIELD),
            BillingState: getFieldValue(accountData, ACCOUNT_BILLING_STATE_FIELD),
            BillingPostalCode: getFieldValue(accountData, ACCOUNT_BILLING_POSTAL_CODE_FIELD),
            BillingCountry: getFieldValue(accountData, ACCOUNT_BILLING_COUNTRY_FIELD)
        };
    }

    // Tab navigation handlers
    handleTabClick(event) {
        this.activeTab = event.target.dataset.tab;
    }

    // Edit mode handlers
    handleEditProfile() {
        this.isEditing = true;
    }

    handleCancelEdit() {
        this.isEditing = false;
        this.initializeEditableAccount(this.account);
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.editableAccount = { ...this.editableAccount, [field]: value };
    }

    async handleSaveProfile() {
        this.isSaving = true;
        try {
            const recordInput = {
                fields: this.editableAccount
            };
            
            await updateRecord(recordInput);
            
            // Refresh the wired data
            await refreshApex(this.wiredAccountResult);
            
            this.isEditing = false;
            this.showSuccessToast('Profile Updated', 'Your profile has been successfully updated.');
        } catch (error) {
            this.showErrorToast('Update Failed', error.body?.message || error.message);
        } finally {
            this.isSaving = false;
        }
    }

    // Credit score request handler
    async handleRequestCreditScore() {
        this.isRequestingScore = true;
        try {
            await createCreditScoreRequest({ 
                accountId: this.recordId,
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

//__________________________GenAI: Generated code ends here______________________________
