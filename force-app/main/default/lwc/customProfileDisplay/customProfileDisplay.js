//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Account fields to display
import ACCOUNT_ID from '@salesforce/schema/Account.Id';
import FIRST_NAME from '@salesforce/schema/Account.FirstName';
import LAST_NAME from '@salesforce/schema/Account.LastName';
import PERSON_EMAIL from '@salesforce/schema/Account.PersonEmail';
import PHONE from '@salesforce/schema/Account.Phone';
import AGE_FIELD from '@salesforce/schema/Account.Age__c';
import BILLING_STREET from '@salesforce/schema/Account.BillingStreet';
import BILLING_CITY from '@salesforce/schema/Account.BillingCity';
import BILLING_STATE from '@salesforce/schema/Account.BillingState';
import BILLING_POSTAL_CODE from '@salesforce/schema/Account.BillingPostalCode';
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
    BILLING_STREET,
    BILLING_CITY,
    BILLING_STATE,
    BILLING_POSTAL_CODE,
    CURRENT_CREDIT_SCORE,
    LAST_SCORE_CALCULATION,
    EXTERNAL_CUSTOMER_ID
];

const USER_FIELDS = [
    'User.Id',
    'User.ContactId',
    'User.Contact.AccountId'
];

export default class CustomProfileDisplay extends LightningElement {
    @api recordId;
    @track isEditing = false;
    @track isLoading = true;
    @track accountData = {};
    @track editData = {};
    @track userAccountId;
    
    wiredUserResult;
    wiredAccountResult;

    // First, get the current user's Account ID
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
                
                // If still not found, we need to query the Contact record separately
                if (!this.userAccountId) {
                    console.log('Account ID not found in user data, will need to query Contact');
                    this.getAccountIdFromContact(contactId);
                }
            } else {
                console.log('No ContactId found for user');
            }
        } else if (result.error) {
            console.error('Error fetching user data:', result.error);
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
                billingStreet: result.data.fields.BillingStreet.value,
                billingCity: result.data.fields.BillingCity.value,
                billingState: result.data.fields.BillingState.value,
                billingPostalCode: result.data.fields.BillingPostalCode.value,
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
            const fields = {};
            fields[ACCOUNT_ID.fieldApiName] = this.effectiveRecordId;
            
            // Only update fields that have changed and are editable
            if (this.editData.firstName !== this.accountData.firstName) {
                fields[FIRST_NAME.fieldApiName] = this.editData.firstName;
            }
            if (this.editData.lastName !== this.accountData.lastName) {
                fields[LAST_NAME.fieldApiName] = this.editData.lastName;
            }
            if (this.editData.personEmail !== this.accountData.personEmail) {
                fields[PERSON_EMAIL.fieldApiName] = this.editData.personEmail;
            }
            if (this.editData.phone !== this.accountData.phone) {
                fields[PHONE.fieldApiName] = this.editData.phone;
            }
            if (this.editData.age !== this.accountData.age) {
                fields[AGE_FIELD.fieldApiName] = this.editData.age ? parseInt(this.editData.age) : null;
            }
            if (this.editData.billingStreet !== this.accountData.billingStreet) {
                fields[BILLING_STREET.fieldApiName] = this.editData.billingStreet;
            }
            if (this.editData.billingCity !== this.accountData.billingCity) {
                fields[BILLING_CITY.fieldApiName] = this.editData.billingCity;
            }
            if (this.editData.billingState !== this.accountData.billingState) {
                fields[BILLING_STATE.fieldApiName] = this.editData.billingState;
            }
            if (this.editData.billingPostalCode !== this.accountData.billingPostalCode) {
                fields[BILLING_POSTAL_CODE.fieldApiName] = this.editData.billingPostalCode;
            }

            const recordInput = { fields };
            await updateRecord(recordInput);
            
            // Refresh the wired data
            await refreshApex(this.wiredAccountResult);
            
            this.isEditing = false;
            this.showToast('Success', 'Profile updated successfully!', 'success');
            
        } catch (error) {
            this.showToast('Error', 'Error updating profile: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
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

//__________________________GenAI: Generated code ends here______________________________
