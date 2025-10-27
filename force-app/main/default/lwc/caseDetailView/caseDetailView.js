import { LightningElement, api, wire, track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';

// Import Apex methods
import updateCaseRecord from '@salesforce/apex/CaseUpdateService.updateCaseRecord';
import getCaseRecord from '@salesforce/apex/CaseUpdateService.getCaseRecord';

export default class CaseDetailView extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isLoading = false;
    @track isEditing = false;
    @track isEditLoading = false;
    @track error;
    @track currentRecordId;

    // Wire current page reference to get URL parameters
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            if (!this.recordId) {
                this.currentRecordId = currentPageReference.state?.recordId || 
                                     currentPageReference.attributes?.recordId ||
                                     this.extractRecordIdFromUrl(currentPageReference);
            } else {
                this.currentRecordId = this.recordId;
            }
        }
    }

    // Case data from Apex method
    @track caseData;

    // Getters for field values
    get caseNumber() {
        return this.caseData?.CaseNumber;
    }

    get subject() {
        return this.caseData?.Subject;
    }

    get description() {
        return this.caseData?.Description;
    }

    get comments() {
        return this.caseData?.Comments;
    }

    get status() {
        return this.caseData?.Status;
    }

    get priority() {
        return this.caseData?.Priority;
    }

    get origin() {
        return this.caseData?.Origin;
    }

    get type() {
        return this.caseData?.Type;
    }

    get reason() {
        return this.caseData?.Reason;
    }

    get createdDate() {
        const date = this.caseData?.CreatedDate;
        return date ? this.formatDateTime(date) : '';
    }

    get lastModifiedDate() {
        const date = this.caseData?.LastModifiedDate;
        return date ? this.formatDateTime(date) : '';
    }

    get closedDate() {
        const date = this.caseData?.ClosedDate;
        return date ? this.formatDateTime(date) : 'Not Closed';
    }

    get ownerName() {
        const owner = this.caseData?.Owner;
        if (owner && owner.FirstName && owner.LastName) {
            return `${owner.FirstName} ${owner.LastName}`;
        } else if (owner && owner.Name) {
            return owner.Name;
        }
        return 'Not assigned';
    }

    get accountName() {
        return this.caseData?.Account?.Name || '';
    }

    get contactName() {
        return this.caseData?.Contact?.Name || '';
    }

    get contactEmail() {
        return this.caseData?.Contact?.Email || '';
    }

    get contactPhone() {
        return this.caseData?.Contact?.Phone || '';
    }

    get accountId() {
        return this.caseData?.AccountId;
    }

    get contactId() {
        return this.caseData?.ContactId;
    }

    // Status styling
    get statusClass() {
        const status = this.status;
        switch (status?.toLowerCase()) {
            case 'new':
                return 'slds-badge slds-badge_lightest';
            case 'working':
                return 'slds-badge slds-theme_warning';
            case 'escalated':
                return 'slds-badge slds-theme_error';
            case 'closed':
                return 'slds-badge slds-theme_success';
            default:
                return 'slds-badge';
        }
    }

    get priorityClass() {
        const priority = this.priority;
        switch (priority?.toLowerCase()) {
            case 'high':
                return 'priority-high';
            case 'medium':
                return 'priority-medium';
            case 'low':
                return 'priority-low';
            default:
                return 'priority-normal';
        }
    }

    get isClosed() {
        return this.status?.toLowerCase() === 'closed';
    }

    get effectiveRecordId() {
        return this.recordId || this.currentRecordId;
    }

    // Event Handlers
    handleEdit() {
        this.isEditLoading = true;
        
        // Simulate loading time for modal preparation
        setTimeout(() => {
            this.isEditing = true;
            this.isEditLoading = false;
        }, 500); // 500ms delay to show loading state
    }

    handleCancel() {
        this.isEditing = false;
    }

    handleSave(event) {
        // Handle success from lightning-record-edit-form
        this.showToast('Success', 'Case updated successfully', 'success');
        this.isEditing = false;
        
        // Refresh the record to show updated data
        this.refreshRecord();
    }

    handleError(event) {
        // Handle error from lightning-record-edit-form
        const errorMessage = event.detail?.detail || event.detail?.message || 'An error occurred while saving the case';
        this.showToast('Error', errorMessage, 'error');
    }

    handleLoad() {
        // Handle load event from lightning-record-edit-form
        this.isLoading = false;
    }

    handleSubmit(event) {
        // Handle submit event from lightning-record-edit-form
        this.isLoading = true;
        
        // Get the field values from the form
        const fields = event.detail.fields;
        
        // Prevent default form submission to handle it manually
        event.preventDefault();
        
        // Call Apex method to update the case record
        updateCaseRecord({
            caseId: this.effectiveRecordId,
            caseType: fields.Type || '',
            origin: fields.Origin || '',
            description: fields.Description || '',
            comments: fields.Comments || ''
        })
        .then(result => {
            if (result === 'SUCCESS') {
                this.showToast('Success', 'Case updated successfully', 'success');
                this.isEditing = false;
                
                // Refresh the entire page to show updated data
                setTimeout(() => {
                    window.location.reload();
                }, 1000); // Small delay to show the success toast
            } else {
                throw new Error('Unexpected response from server');
            }
        })
        .catch(error => {
            console.error('Error updating case:', error);
            this.showToast('Error', 'Failed to update case: ' + (error.body?.message || error.message), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleNavigateToAccount() {
        if (this.accountId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.accountId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        }
    }

    handleNavigateToContact() {
        if (this.contactId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.contactId,
                    objectApiName: 'Contact',
                    actionName: 'view'
                }
            });
        }
    }

    handleCloseCase() {
        this.isLoading = true;
        const fields = {
            Id: this.effectiveRecordId,
            Status: 'Closed'
        };

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                this.showToast('Success', 'Case closed successfully', 'success');
                return this.refreshRecord();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to close case: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleReopenCase() {
        this.isLoading = true;
        const fields = {
            Id: this.effectiveRecordId,
            Status: 'Working'
        };

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                this.showToast('Success', 'Case reopened successfully', 'success');
                return this.refreshRecord();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to reopen case: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Utility Methods
    extractRecordIdFromUrl(currentPageReference) {
        if (currentPageReference && currentPageReference.attributes) {
            if (currentPageReference.attributes.recordId) {
                return currentPageReference.attributes.recordId;
            }
            
            if (currentPageReference.attributes.name) {
                const urlPath = currentPageReference.attributes.name;
                const recordIdMatch = urlPath.match(/([a-zA-Z0-9]{15,18})/);
                if (recordIdMatch) {
                    return recordIdMatch[1];
                }
            }
        }
        
        if (currentPageReference && currentPageReference.state) {
            return currentPageReference.state.recordId || 
                   currentPageReference.state.c__recordId ||
                   currentPageReference.state.id;
        }
        
        return null;
    }

    formatDateTime(dateTimeValue) {
        if (!dateTimeValue) return '';
        try {
            const date = new Date(dateTimeValue);
            return date.toLocaleString();
        } catch (error) {
            return 'Invalid Date';
        }
    }

    refreshRecord() {
        this.loadCaseDetails();
        return Promise.resolve();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    // Handle errors
    get hasError() {
        return this.error;
    }

    get errorMessage() {
        return this.error?.body?.message || this.error?.message || 'An error occurred loading case details';
    }

    // Lifecycle Methods
    connectedCallback() {
        this.loadCaseDetails();
    }

    // Load case details using Apex method
    loadCaseDetails() {
        const caseId = this.effectiveRecordId;
        if (!caseId) {
            console.log('No case ID available for loading case details');
            return;
        }

        console.log('Loading case details for case ID:', caseId);
        this.isLoading = true;
        this.error = null;

        getCaseRecord({ caseId })
            .then(result => {
                console.log('Case details loaded successfully:', result);
                this.caseData = result;
            })
            .catch(error => {
                console.error('Error loading case details:', error);
                this.error = error;
                this.showToast('Error', 'Failed to load case details: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}