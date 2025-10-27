import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';

// Credit Score Request fields
import CREDIT_REQUEST_ID_FIELD from '@salesforce/schema/Credit_Score_Request__c.Id';
import CREDIT_REQUEST_NAME_FIELD from '@salesforce/schema/Credit_Score_Request__c.Name';
import CREDIT_REQUEST_CUSTOMER_FIELD from '@salesforce/schema/Credit_Score_Request__c.Customer__c';
import CREDIT_REQUEST_STATUS_FIELD from '@salesforce/schema/Credit_Score_Request__c.Request_Status__c';
import CREDIT_REQUEST_CHANNEL_FIELD from '@salesforce/schema/Credit_Score_Request__c.Request_Channel__c';
import CREDIT_REQUEST_CREATED_DATE_FIELD from '@salesforce/schema/Credit_Score_Request__c.CreatedDate';
import CREDIT_REQUEST_LAST_MODIFIED_DATE_FIELD from '@salesforce/schema/Credit_Score_Request__c.LastModifiedDate';
import CREDIT_REQUEST_COMPLETED_DATE_FIELD from '@salesforce/schema/Credit_Score_Request__c.Completed_Date__c';
import CREDIT_REQUEST_PROCESSING_NOTES_FIELD from '@salesforce/schema/Credit_Score_Request__c.Processing_Notes__c';
import CREDIT_REQUEST_REQUESTED_DATE_FIELD from '@salesforce/schema/Credit_Score_Request__c.Requested_Date__c';
import CREDIT_REQUEST_RESULT_FIELD from '@salesforce/schema/Credit_Score_Request__c.Credit_Score_Result__c';

const CREDIT_REQUEST_FIELDS = [
    'Credit_Score_Request__c.Id',
    'Credit_Score_Request__c.Name',
    'Credit_Score_Request__c.Customer__c',
    'Credit_Score_Request__c.Customer__r.Name',
    'Credit_Score_Request__c.Customer__r.Email__c',
    'Credit_Score_Request__c.Customer__r.Phone',
    'Credit_Score_Request__c.Request_Status__c',
    'Credit_Score_Request__c.Request_Channel__c',
    'Credit_Score_Request__c.CreatedDate',
    'Credit_Score_Request__c.LastModifiedDate',
    'Credit_Score_Request__c.Completed_Date__c',
    'Credit_Score_Request__c.Processing_Notes__c',
    'Credit_Score_Request__c.Requested_Date__c',
    'Credit_Score_Request__c.Credit_Score_Result__c',
    'Credit_Score_Request__c.Credit_Score_Result__r.Total_Score__c'
];

export default class CreditRequestDetailView extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isLoading = false;
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

    // Wire the credit request record
    @wire(getRecord, { recordId: '$currentRecordId', fields: CREDIT_REQUEST_FIELDS })
    creditRequestRecord;

    // Getters for field values
    get requestName() {
        return getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_NAME_FIELD);
    }

    get customerId() {
        return getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_CUSTOMER_FIELD);
    }

    get customerName() {
        return this.creditRequestRecord.data?.fields?.Customer__r?.value?.fields?.Name?.value || '';
    }

    get customerEmail() {
        return this.creditRequestRecord.data?.fields?.Customer__r?.value?.fields?.Email?.value || '';
    }

    get customerPhone() {
        return this.creditRequestRecord.data?.fields?.Customer__r?.value?.fields?.Phone?.value || '';
    }

    get status() {
        return getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_STATUS_FIELD);
    }

    get requestChannel() {
        return getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_CHANNEL_FIELD);
    }

    get creditScore() {
        return this.creditRequestRecord.data?.fields?.Credit_Score_Result__r?.value?.fields?.Total_Score__c?.value || null;
    }

    get processingNotes() {
        return getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_PROCESSING_NOTES_FIELD);
    }

    get createdDate() {
        const date = getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_CREATED_DATE_FIELD);
        return date ? this.formatDateTime(date) : '';
    }

    get lastModifiedDate() {
        const date = getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_LAST_MODIFIED_DATE_FIELD);
        return date ? this.formatDateTime(date) : '';
    }

    get completedDate() {
        const date = getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_COMPLETED_DATE_FIELD);
        return date ? this.formatDateTime(date) : 'Not Completed';
    }

    get requestedDate() {
        const date = getFieldValue(this.creditRequestRecord.data, CREDIT_REQUEST_REQUESTED_DATE_FIELD);
        return date ? this.formatDateTime(date) : '';
    }

    // Status styling
    get statusClass() {
        const status = this.status;
        switch (status?.toLowerCase()) {
            case 'submitted':
                return 'slds-badge slds-badge_lightest';
            case 'processing':
                return 'slds-badge slds-theme_warning';
            case 'completed':
                return 'slds-badge slds-theme_success';
            case 'failed':
                return 'slds-badge slds-theme_error';
            default:
                return 'slds-badge';
        }
    }

    get channelClass() {
        const channel = this.requestChannel;
        switch (channel?.toLowerCase()) {
            case 'web':
                return 'channel-web';
            case 'email':
                return 'channel-email';
            case 'phone':
                return 'channel-phone';
            case 'mobile':
                return 'channel-mobile';
            default:
                return 'channel-default';
        }
    }

    get creditScoreClass() {
        const score = this.creditScore;
        if (!score) return 'score-unknown';
        
        if (score >= 600) return 'score-excellent';
        if (score >= 450) return 'score-good';
        if (score >= 300) return 'score-poor';
        return 'score-unknown';
    }

    get creditScoreStatus() {
        const score = this.creditScore;
        if (!score) return 'Unknown';
        
        if (score >= 600) return 'Excellent';
        if (score >= 450) return 'Good';
        if (score >= 300) return 'Poor';
        return 'Unknown';
    }

    // Gauge-specific getters
    get scorePercentage() {
        // Calculate percentage based on 300-750 range
        const minScore = 300;
        const maxScore = 750;
        const percentage = ((this.creditScore - minScore) / (maxScore - minScore)) * 100;
        return Math.max(0, Math.min(100, Math.round(percentage)));
    }

    get gaugeColor() {
        const score = this.creditScore;
        if (!score) return '#6c757d'; // Gray
        
        if (score >= 600) return '#28a745'; // Success green
        if (score >= 450) return '#ffc107'; // Warning yellow
        if (score >= 300) return '#dc3545'; // Danger red
        return '#6c757d'; // Gray
    }

    get gaugeDashArray() {
        // Semi-circle circumference calculation
        const radius = 80;
        const circumference = Math.PI * radius; // Half circle
        return `${circumference} ${circumference}`;
    }

    get gaugeDashOffset() {
        // Calculate offset based on percentage
        const radius = 80;
        const circumference = Math.PI * radius;
        const offset = circumference - (this.scorePercentage / 100) * circumference;
        return offset;
    }

    get scoreStatusClass() {
        const status = this.creditScoreStatus.toLowerCase();
        switch (status) {
            case 'excellent':
                return 'score-status status-excellent';
            case 'good':
                return 'score-status status-good';
            case 'poor':
                return 'score-status status-poor';
            default:
                return 'score-status status-unknown';
        }
    }

    get scoreRangeText() {
        // Return the score range based on current status
        const score = this.creditScore;
        if (!score) return 'N/A';
        
        if (score >= 600) return '600-750';
        if (score >= 450) return '450-600';
        if (score >= 300) return '300-450';
        return 'N/A';
    }

    get isCompleted() {
        return this.status?.toLowerCase() === 'completed';
    }

    get isProcessing() {
        return this.status?.toLowerCase() === 'processing';
    }

    get isFailed() {
        return this.status?.toLowerCase() === 'failed';
    }

    get effectiveRecordId() {
        return this.recordId || this.currentRecordId;
    }

    // Event Handlers
    handleNavigateToCustomer() {
        if (this.customerId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.customerId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        }
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
        return this.creditRequestRecord.refresh?.() || Promise.resolve();
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
        return this.creditRequestRecord.error || this.error;
    }

    get errorMessage() {
        return this.creditRequestRecord.error?.body?.message || this.error?.message || 'An error occurred';
    }

    // Lifecycle Methods
    connectedCallback() {
        if (!this.effectiveRecordId) {
            console.warn('CreditRequestDetailView: No recordId provided');
        }
    }
}
