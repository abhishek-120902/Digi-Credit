import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

// Import Apex methods
import updateAccountProfile from '@salesforce/apex/CreditScoreCalculationService.updateAccountProfile';

// Account fields to display
import ACCOUNT_ID from '@salesforce/schema/Account.Id';
import FIRST_NAME from '@salesforce/schema/Account.FirstName';
import LAST_NAME from '@salesforce/schema/Account.LastName';
import PERSON_EMAIL from '@salesforce/schema/Account.PersonEmail';
import PHONE from '@salesforce/schema/Account.Phone';
import AGE_FIELD from '@salesforce/schema/Account.Age__c';
import CURRENT_CREDIT_SCORE from '@salesforce/schema/Account.Current_Credit_Score__c';
import LAST_SCORE_CALCULATION from '@salesforce/schema/Account.Last_Score_Calculation__c';
import EXTERNAL_CUSTOMER_ID from '@salesforce/schema/Account.External_Customer_ID__c';

// Get current user ID
import USER_ID from '@salesforce/user/Id';

const ACCOUNT_FIELDS = [
    ACCOUNT_ID,
    FIRST_NAME,
    LAST_NAME,
    PERSON_EMAIL,
    PHONE,
    AGE_FIELD,
    CURRENT_CREDIT_SCORE,
    LAST_SCORE_CALCULATION,
    EXTERNAL_CUSTOMER_ID
];

const USER_FIELDS = [
    'User.Id',
    'User.ContactId',
    'User.Contact.AccountId'
];

export default class CustomProfileDisplay extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isEditing = false;
    @track isLoading = true;
    @track accountData = {};
    @track editData = {};
    @track userAccountId;
    
    wiredUserResult;
    wiredAccountResult;

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
            this.showToast('Error', 'Error loading user data. Please ensure you have the required permissions.', 'error');
            this.isLoading = false;
        }
    }

    // Then get the Account record using either recordId or userAccountId
    @wire(getRecord, { recordId: '$effectiveRecordId', fields: ACCOUNT_FIELDS })
    wiredAccount(result) {
        this.wiredAccountResult = result;
        if (result.data) {
            this.accountData = {
                id: result.data.fields.Id.value,
                firstName: result.data.fields.FirstName.value,
                lastName: result.data.fields.LastName.value,
                personEmail: result.data.fields.PersonEmail.value,
                phone: result.data.fields.Phone.value,
                age: result.data.fields.Age__c.value,
                currentCreditScore: result.data.fields.Current_Credit_Score__c.value,
                lastScoreCalculation: result.data.fields.Last_Score_Calculation__c.value,
                externalCustomerId: result.data.fields.External_Customer_ID__c.value
            };
            this.editData = { ...this.accountData };
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error loading account data:', result.error);
            this.showToast('Error', 'Error loading profile data: ' + result.error.body?.message || result.error.message, 'error');
            this.isLoading = false;
        }
    }

    // Use recordId if provided, otherwise use current user's Account ID
    get effectiveRecordId() {
        return this.recordId || this.userAccountId;
    }

    get displayName() {
        if (this.accountData.firstName && this.accountData.lastName) {
            return `${this.accountData.firstName} ${this.accountData.lastName}`;
        }
        return 'Profile Information';
    }

    get formattedCreditScore() {
        return this.accountData.currentCreditScore ? this.accountData.currentCreditScore.toString() : 'Not Available';
    }

    get formattedLastCalculation() {
        if (this.accountData.lastScoreCalculation) {
            return new Date(this.accountData.lastScoreCalculation).toLocaleDateString();
        }
        return 'Never';
    }

    get creditScoreClass() {
        const score = this.accountData.currentCreditScore;
        if (score >= 600) return 'score-excellent';
        if (score >= 450) return 'score-good';
        return 'score-poor';
    }

    handleEdit() {
        this.isEditing = true;
        this.editData = { ...this.accountData };
    }

    handleCancel() {
        this.isEditing = false;
        this.editData = { ...this.accountData };
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.editData = { ...this.editData, [field]: value };
    }

    async handleSave() {
        this.isLoading = true;
        
        try {
            // Validate that we have a record ID
            if (!this.effectiveRecordId) {
                throw new Error('No record ID available for update');
            }

            // Prepare profile data for Apex method
            const profileData = {};
            let hasChanges = false;
            
            // Only include fields that have changed
            if (this.editData.firstName !== this.accountData.firstName) {
                profileData.firstName = this.editData.firstName;
                hasChanges = true;
            }
            if (this.editData.lastName !== this.accountData.lastName) {
                profileData.lastName = this.editData.lastName;
                hasChanges = true;
            }
            if (this.editData.personEmail !== this.accountData.personEmail) {
                profileData.personEmail = this.editData.personEmail;
                hasChanges = true;
            }
            if (this.editData.phone !== this.accountData.phone) {
                profileData.phone = this.editData.phone;
                hasChanges = true;
            }
            if (this.editData.age !== this.accountData.age) {
                profileData.age = this.editData.age ? parseInt(this.editData.age) : null;
                hasChanges = true;
            }

            // Check if there are any changes to save
            if (!hasChanges) {
                this.isEditing = false;
                this.showToast('Info', 'No changes to save', 'info');
                return;
            }

            console.log('Updating profile with data:', JSON.stringify(profileData, null, 2));
            
            // Call Apex method to update the account
            const result = await updateAccountProfile({
                accountId: this.effectiveRecordId,
                profileData: profileData
            });
            
            console.log('Update result:', result);
            
            // Refresh the wired data to show updated values
            await refreshApex(this.wiredAccountResult);
            
            this.isEditing = false;
            this.showToast('Success', result || 'Profile updated successfully!', 'success');
            
        } catch (error) {
            console.error('Error updating profile:', error);
            
            let errorMessage = 'An error occurred while updating your profile. Please try again.';
            
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Navigation methods
    handleNavigateToDashboard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/home'
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

    handleNavigateToRequestScore() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/request-score'
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
            variant: variant
        });
        this.dispatchEvent(event);
    }
}
