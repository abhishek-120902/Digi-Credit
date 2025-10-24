import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

// Import Apex methods
import getCaseHistory from '@salesforce/apex/SupportCaseService.getCaseHistory';
import createSupportCase from '@salesforce/apex/SupportCaseService.createSupportCase';

// Get current user ID
import USER_ID from '@salesforce/user/Id';

// User fields for getting Account ID
const USER_FIELDS = [
    'User.Id',
    'User.ContactId',
    'User.Contact.AccountId'
];

export default class SupportCaseHistory extends NavigationMixin(LightningElement) {
    @api recordId; // Account ID - can be passed from parent
    @api cardTitle = 'Support Case History';
    
    @track isLoading = false;
    @track isCreatingCase = false;
    @track caseHistory = [];
    @track error;
    @track userAccountId;
    @track showNewCaseModal = false;
    @track newCaseSubject = '';
    @track newCaseDescription = '';
    @track newCasePriority = 'Medium';
    
    wiredUserResult;
    wiredCaseResult;

    // Priority options for new case
    priorityOptions = [
        { label: 'Low', value: 'Low' },
        { label: 'Medium', value: 'Medium' },
        { label: 'High', value: 'High' },
        { label: 'Critical', value: 'Critical' }
    ];

    // Get the current user's Account ID
    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    wiredUser(result) {
        this.wiredUserResult = result;
        
        if (result.data) {
            // Get Account ID from User's Contact
            if (result.data.fields.ContactId && result.data.fields.ContactId.value) {
                // Try to get Account ID from Contact relationship
                if (result.data.fields.Contact && result.data.fields.Contact.value) {
                    if (result.data.fields.Contact.value.fields && 
                        result.data.fields.Contact.value.fields.AccountId) {
                        this.userAccountId = result.data.fields.Contact.value.fields.AccountId.value;
                    }
                }
            }
        } else if (result.error) {
            console.error('Error fetching user data:', result.error);
            this.error = result.error;
        }
    }

    // Wire case history
    @wire(getCaseHistory, { accountId: '$effectiveAccountId' })
    wiredCaseHistory(result) {
        this.wiredCaseResult = result;
        this.isLoading = true;
        
        if (result.data) {
            this.caseHistory = result.data.map(caseRecord => ({
                ...caseRecord,
                formattedCreatedDate: this.formatDateTime(caseRecord.CreatedDate),
                formattedClosedDate: this.formatDateTime(caseRecord.ClosedDate),
                statusClass: this.getCaseStatusClass(caseRecord.Status),
                priorityClass: this.getCasePriorityClass(caseRecord.Priority),
                hasDescription: caseRecord.Description && caseRecord.Description.length > 0,
                truncatedDescription: this.truncateText(caseRecord.Description, 100)
            }));
            this.error = null;
        } else if (result.error) {
            this.error = result.error;
            this.caseHistory = [];
        }
        
        this.isLoading = false;
    }

    // Use recordId if provided, otherwise use current user's Account ID
    get effectiveAccountId() {
        return this.recordId || this.userAccountId;
    }

    get hasCases() {
        return this.caseHistory && this.caseHistory.length > 0;
    }

    get isNewCaseFormValid() {
        return this.newCaseSubject && this.newCaseSubject.trim().length > 0 &&
               this.newCaseDescription && this.newCaseDescription.trim().length > 0;
    }

    // Event handlers
    handleNewCaseClick() {
        this.showNewCaseModal = true;
        this.resetNewCaseForm();
    }

    handleCloseModal() {
        this.showNewCaseModal = false;
        this.resetNewCaseForm();
    }

    handleSubjectChange(event) {
        this.newCaseSubject = event.target.value;
    }

    handleDescriptionChange(event) {
        this.newCaseDescription = event.target.value;
    }

    handlePriorityChange(event) {
        this.newCasePriority = event.detail.value;
    }

    async handleCreateCase() {
        if (!this.isNewCaseFormValid) {
            this.showErrorToast('Validation Error', 'Please fill in all required fields.');
            return;
        }

        this.isCreatingCase = true;

        try {
            await createSupportCase({
                accountId: this.effectiveAccountId,
                subject: this.newCaseSubject.trim(),
                description: this.newCaseDescription.trim(),
                priority: this.newCasePriority
            });

            // Refresh case history
            await refreshApex(this.wiredCaseResult);

            this.showSuccessToast('Success', 'Support case created successfully!');
            this.handleCloseModal();

        } catch (error) {
            console.error('Error creating case:', error);
            this.showErrorToast('Error', error.body?.message || error.message || 'Failed to create support case');
        } finally {
            this.isCreatingCase = false;
        }
    }

    handleViewCase(event) {
        const caseId = event.target.dataset.id;
        
        // Navigate to case record page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredCaseResult);
    }

    // Utility methods
    resetNewCaseForm() {
        this.newCaseSubject = '';
        this.newCaseDescription = '';
        this.newCasePriority = 'Medium';
    }

    formatDateTime(dateTimeValue) {
        if (!dateTimeValue) return '';
        return new Date(dateTimeValue).toLocaleString();
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        return new Date(dateValue).toLocaleDateString();
    }

    truncateText(text, maxLength) {
        if (!text) return '';
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
    }

    getCaseStatusClass(status) {
        switch (status) {
            case 'New':
                return 'slds-badge slds-theme_info';
            case 'In Progress':
            case 'Working':
                return 'slds-badge slds-theme_warning';
            case 'Closed':
            case 'Solved':
                return 'slds-badge slds-theme_success';
            case 'Escalated':
                return 'slds-badge slds-theme_error';
            default:
                return 'slds-badge';
        }
    }

    getCasePriorityClass(priority) {
        switch (priority) {
            case 'Critical':
                return 'priority-critical';
            case 'High':
                return 'priority-high';
            case 'Medium':
                return 'priority-medium';
            case 'Low':
                return 'priority-low';
            default:
                return 'priority-medium';
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