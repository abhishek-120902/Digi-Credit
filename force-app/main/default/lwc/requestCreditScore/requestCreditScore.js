//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord } from 'lightning/uiRecordApi';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';

// Import User ID
import USER_ID from '@salesforce/user/Id';

// Import Account fields to get current user's account
import ACCOUNT_ID from '@salesforce/schema/Account.Id';
import ACCOUNT_NAME from '@salesforce/schema/Account.Name';

// Import Credit Score Request object and fields
import CREDIT_SCORE_REQUEST_OBJECT from '@salesforce/schema/Credit_Score_Request__c';
import CUSTOMER_FIELD from '@salesforce/schema/Credit_Score_Request__c.Customer__c';
import REQUEST_CHANNEL_FIELD from '@salesforce/schema/Credit_Score_Request__c.Request_Channel__c';
import REQUEST_STATUS_FIELD from '@salesforce/schema/Credit_Score_Request__c.Request_Status__c';
import REQUESTED_DATE_FIELD from '@salesforce/schema/Credit_Score_Request__c.Requested_Date__c';

export default class RequestCreditScore extends NavigationMixin(LightningElement) {
    @track formData = {
        requestChannel: '',
        reason: '',
        agreeToTerms: false
    };
    
    @track isLoading = false;
    @track isSubmitting = false;
    @track showSuccessMessage = false;
    @track userAccountId = '';
    @track userName = '';

    // Channel options for the picklist
    channelOptions = [
        { label: 'Select Channel', value: '' },
        { label: 'Web Portal', value: 'Web' },
        { label: 'Mobile App', value: 'Mobile App' },
        { label: 'Email Request', value: 'Email' },
        { label: 'Phone Request', value: 'Phone' }
    ];

    // Wire to get current user's account information
    @wire(getRecord, { 
        recordId: USER_ID, 
        fields: ['User.ContactId', 'User.Contact.AccountId', 'User.Contact.Account.Name'] 
    })
    wiredUser({ error, data }) {
        if (data) {
            if (data.fields.ContactId && data.fields.ContactId.value) {
                // Get account ID from contact
                this.userAccountId = data.fields.Contact?.value?.fields?.AccountId?.value;
                this.userName = data.fields.Contact?.value?.fields?.Account?.value?.fields?.Name?.value || 'Customer';
            }
        } else if (error) {
            console.error('Error fetching user data:', error);
        }
    }

    get isFormValid() {
        return this.formData.requestChannel && 
               this.formData.agreeToTerms && 
               this.userAccountId;
    }

    get submitButtonClass() {
        return `submit-button ${this.isFormValid ? 'enabled' : 'disabled'}`;
    }

    get welcomeMessage() {
        return this.userName ? `Welcome, ${this.userName}` : 'Welcome';
    }

    handleChannelChange(event) {
        this.formData.requestChannel = event.target.value;
    }

    handleReasonChange(event) {
        this.formData.reason = event.target.value;
    }

    handleTermsChange(event) {
        this.formData.agreeToTerms = event.target.checked;
    }

    async handleSubmit() {
        if (!this.isFormValid) {
            this.showToast('Error', 'Please fill in all required fields and accept the terms.', 'error');
            return;
        }

        this.isSubmitting = true;

        try {
            // Create Credit Score Request record
            const fields = {};
            fields[CUSTOMER_FIELD.fieldApiName] = this.userAccountId;
            fields[REQUEST_CHANNEL_FIELD.fieldApiName] = this.formData.requestChannel;
            fields[REQUEST_STATUS_FIELD.fieldApiName] = 'Pending';
            fields[REQUESTED_DATE_FIELD.fieldApiName] = new Date().toISOString();

            const recordInput = {
                apiName: CREDIT_SCORE_REQUEST_OBJECT.objectApiName,
                fields
            };

            const result = await createRecord(recordInput);
            
            if (result.id) {
                this.showSuccessMessage = true;
                this.resetForm();
                this.showToast('Success', 'Credit score request submitted successfully! You will receive an email when your score is ready.', 'success');
                
                // Navigate to dashboard after 3 seconds
                setTimeout(() => {
                    this.navigateToDashboard();
                }, 3000);
            }

        } catch (error) {
            console.error('Error creating credit score request:', error);
            this.showToast('Error', 'Failed to submit request: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    resetForm() {
        this.formData = {
            requestChannel: '',
            reason: '',
            agreeToTerms: false
        };
    }

    navigateToDashboard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/home'
            }
        });
    }

    handleBackToDashboard() {
        this.navigateToDashboard();
    }

    handleNavigateToProfile() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/my-profile'
            }
        });
    }

    handleNavigateToCreditScore() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/credit-score'
            }
        });
    }

    handleNavigateToSupport() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/support'
            }
        });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    // Handle form reset
    handleReset() {
        this.resetForm();
        this.showSuccessMessage = false;
    }

    // Get current date for display
    get currentDate() {
        return new Date().toLocaleDateString();
    }

    // Get estimated completion time
    get estimatedCompletion() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        return tomorrow.toLocaleDateString();
    }
}

//__________________________GenAI: Generated code ends here______________________________