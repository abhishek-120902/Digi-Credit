import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';

// Import Apex methods
import getCustomerDetails from '@salesforce/apex/AgentService.getCustomerDetails';
import getCreditScoreHistory from '@salesforce/apex/CreditScoreCalculationService.getCreditScoreHistory';
import calculateCreditScore from '@salesforce/apex/CreditScoreCalculationService.calculateCreditScore';

export default class CustomerDetailView extends NavigationMixin(LightningElement) {
    @api recordId;
    @track creditScoreHistory = [];
    @track isLoading = false;
    @track showCreditHistory = false;
    @track error;
    @track currentRecordId;
    
    // Related lists data
    @track recentCases = [];
    @track recentCreditRequests = [];
    @track recentBillingRecords = [];
    @track casesLoading = false;
    @track requestsLoading = false;
    @track billingLoading = false;

    // Wire current page reference to get URL parameters
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            console.log('Current Page Reference:', JSON.stringify(currentPageReference, null, 2));
            
            // Get recordId from URL parameters if not provided via @api
            if (!this.recordId) {
                // Check URL state parameters
                this.currentRecordId = currentPageReference.state?.recordId || 
                                     currentPageReference.attributes?.recordId ||
                                     this.extractRecordIdFromUrl(currentPageReference);
                console.log('Resolved currentRecordId:', this.currentRecordId);
            } else {
                this.currentRecordId = this.recordId;
                console.log('Using @api recordId:', this.recordId);
            }
        }
    }

    // Account data from Apex method
    @track accountData;
    @track customerDetailsWrapper;

    // Getter for account data
    get account() {
        return this.accountData;
    }

    // Getters for field values
    get accountName() {
        return this.account?.Name;
    }

    get accountPhone() {
        return this.account?.Phone;
    }

    get accountEmail() {
        return this.account?.Email__c;
    }

    get accountType() {
        return this.account?.Type;
    }

    get accountIndustry() {
        return this.account?.Industry;
    }

    get externalCustomerId() {
        return this.account?.External_Customer_ID__c;
    }

    get currentCreditScore() {
        return this.account?.Current_Credit_Score__c;
    }

    get lastCalculation() {
        const date = this.account?.Last_Score_Calculation__c;
        return date ? new Date(date).toLocaleDateString() : 'Never';
    }

    get customerAge() {
        return this.account?.Age__c;
    }

    get accountOwner() {
        const owner = this.account?.Owner;
        if (owner && owner.FirstName && owner.LastName) {
            return `${owner.FirstName} ${owner.LastName}`;
        } else if (owner && owner.Name) {
            return owner.Name;
        }
        return 'Not assigned';
    }

    get createdDate() {
        const date = this.account?.CreatedDate;
        return date ? new Date(date).toLocaleDateString() : '';
    }

    // Credit score status and styling
    get creditScoreStatus() {
        const score = this.currentCreditScore;
        if (!score) return 'Unknown';
        if (score >= 600) return 'Excellent';
        if (score >= 450) return 'Good';
        return 'Poor';
    }

    get creditScoreClass() {
        const status = this.creditScoreStatus;
        return `credit-score ${status.toLowerCase()}`;
    }

    get creditScoreBadgeClass() {
        const status = this.creditScoreStatus;
        return `slds-badge ${status === 'Excellent' ? 'slds-badge_success' : 
                           status === 'Good' ? 'slds-badge_warning' : 'slds-badge_error'}`;
    }

    get creditScoreStatusClass() {
        const status = this.creditScoreStatus.toLowerCase();
        return `score-status status-${status}`;
    }

    get scoreRangeText() {
        const score = this.currentCreditScore;
        if (score >= 600 && score <= 750) {
            return '600-750';
        } else if (score >= 450 && score < 600) {
            return '450-600';
        } else if (score >= 300 && score < 450) {
            return '300-450';
        } else {
            return 'N/A';
        }
    }

    get scorePercentage() {
        // Calculate percentage based on 300-750 range
        const minScore = 300;
        const maxScore = 750;
        const score = this.currentCreditScore || 0;
        const percentage = ((score - minScore) / (maxScore - minScore)) * 100;
        return Math.max(0, Math.min(100, Math.round(percentage)));
    }

    get gaugeColor() {
        const status = this.creditScoreStatus.toLowerCase();
        switch (status) {
            case 'excellent':
                return '#28a745'; // Success green
            case 'good':
                return '#ffc107'; // Warning yellow
            case 'poor':
                return '#dc3545'; // Danger red
            default:
                return '#6c757d'; // Gray
        }
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

    // Extract recordId from URL path
    extractRecordIdFromUrl(currentPageReference) {
        if (currentPageReference && currentPageReference.attributes) {
            // For standard record pages, recordId is in attributes
            if (currentPageReference.attributes.recordId) {
                return currentPageReference.attributes.recordId;
            }
            
            // For community pages with custom URLs like /agent/account/{recordId}/detail
            if (currentPageReference.attributes.name) {
                const urlPath = currentPageReference.attributes.name;
                console.log('URL Path for record extraction:', urlPath);
                
                // Try different patterns for record ID extraction
                // Pattern 1: /account/{recordId}/detail or /account/{recordId}
                let recordIdMatch = urlPath.match(/\/account\/([a-zA-Z0-9]{15,18})/);
                if (recordIdMatch) {
                    console.log('Found record ID from account pattern:', recordIdMatch[1]);
                    return recordIdMatch[1];
                }
                
                // Pattern 2: /customer/{recordId}/detail or /customer/{recordId}
                recordIdMatch = urlPath.match(/\/customer\/([a-zA-Z0-9]{15,18})/);
                if (recordIdMatch) {
                    console.log('Found record ID from customer pattern:', recordIdMatch[1]);
                    return recordIdMatch[1];
                }
                
                // Pattern 3: Any 15-18 character Salesforce ID in the URL
                recordIdMatch = urlPath.match(/([a-zA-Z0-9]{15,18})/);
                if (recordIdMatch) {
                    console.log('Found record ID from general pattern:', recordIdMatch[1]);
                    return recordIdMatch[1];
                }
            }
        }
        
        // Try to extract from URL state
        if (currentPageReference && currentPageReference.state) {
            const stateRecordId = currentPageReference.state.recordId || 
                                 currentPageReference.state.c__recordId ||
                                 currentPageReference.state.id;
            if (stateRecordId) {
                console.log('Found record ID from state:', stateRecordId);
                return stateRecordId;
            }
        }
        
        // Last resort: try to get from browser URL
        try {
            const currentUrl = window.location.href;
            console.log('Current URL:', currentUrl);
            const urlRecordMatch = currentUrl.match(/\/account\/([a-zA-Z0-9]{15,18})/);
            if (urlRecordMatch) {
                console.log('Found record ID from browser URL:', urlRecordMatch[1]);
                return urlRecordMatch[1];
            }
        } catch (error) {
            console.error('Error extracting from browser URL:', error);
        }
        
        console.log('No record ID found in URL');
        return null;
    }

    // Get the effective recordId (from @api or URL)
    get effectiveRecordId() {
        const effectiveId = this.recordId || this.currentRecordId;
        console.log('Effective Record ID:', effectiveId, 'recordId:', this.recordId, 'currentRecordId:', this.currentRecordId);
        return effectiveId;
    }

    // Handle recalculate credit score
    handleRecalculateScore() {
        const accountId = this.effectiveRecordId;
        if (!accountId) {
            this.showToast('Error', 'No account ID available', 'error');
            return;
        }
        
        this.isLoading = true;
        calculateCreditScore({ accountId })
            .then(() => {
                this.showToast('Success', 'Credit score recalculated successfully', 'success');
                // Refresh the record
                return this.refreshRecord();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to recalculate credit score: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Handle view credit history
    handleViewCreditHistory() {
        const accountId = this.effectiveRecordId;
        if (!accountId) {
            this.showToast('Error', 'No account ID available', 'error');
            return;
        }
        
        this.isLoading = true;
        getCreditScoreHistory({ accountId, limitRecords: 10 })
            .then(result => {
                this.creditScoreHistory = result.map(score => ({
                    ...score,
                    formattedDate: new Date(score.Calculation_Date__c).toLocaleDateString(),
                    statusClass: this.getScoreStatusClass(score.Total_Score__c)
                }));
                this.showCreditHistory = true;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load credit history: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Handle close credit history
    handleCloseCreditHistory() {
        this.showCreditHistory = false;
    }

    // Navigate to related records
    handleViewCases() {
        const recordId = this.effectiveRecordId;
        if (!recordId) {
            this.showToast('Error', 'No account ID available', 'error');
            return;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId,
                objectApiName: 'Account',
                relationshipApiName: 'Cases',
                actionName: 'view'
            }
        });
    }

    handleViewBillingRecords() {
        const recordId = this.effectiveRecordId;
        if (!recordId) {
            this.showToast('Error', 'No account ID available', 'error');
            return;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId,
                objectApiName: 'Account',
                relationshipApiName: 'Billing_Records__r',
                actionName: 'view'
            }
        });
    }

    // Edit customer
    handleEditCustomer() {
        const recordId = this.effectiveRecordId;
        if (!recordId) {
            this.showToast('Error', 'No account ID available', 'error');
            return;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Account',
                actionName: 'edit'
            }
        });
    }

    // Helper methods
    getScoreStatusClass(score) {
        if (!score) return 'unknown';
        if (score >= 600) return 'excellent';
        if (score >= 450) return 'good';
        return 'poor';
    }

    refreshRecord() {
        // Refresh customer details by calling the Apex method again
        this.loadCustomerDetails();
        return Promise.resolve();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    // Lifecycle methods
    connectedCallback() {
        // Load customer details when component is connected
        this.loadCustomerDetails();
    }

    // Load customer details using single Apex method
    loadCustomerDetails() {
        const accountId = this.effectiveRecordId;
        if (!accountId) {
            console.log('No account ID available for loading customer details');
            return;
        }

        console.log('Loading customer details for account ID:', accountId);
        this.isLoading = true;
        this.error = null;

        getCustomerDetails({ accountId })
            .then(result => {
                console.log('Customer details loaded successfully:', result);
                this.customerDetailsWrapper = result;
                this.accountData = result.customer;

                // Process related lists
                this.processRelatedLists(result);
            })
            .catch(error => {
                console.error('Error loading customer details:', error);
                this.error = error;
                this.showToast('Error', 'Failed to load customer details: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Process related lists from customer details wrapper
    processRelatedLists(customerDetails) {
        // Process cases
        this.recentCases = customerDetails.cases?.map((caseRecord, index) => ({
            ...caseRecord,
            statusClass: this.getCaseStatusClass(caseRecord.Status),
            priorityClass: this.getCasePriorityClass(caseRecord.Priority),
            index: index
        })) || [];

        // Process credit requests
        this.recentCreditRequests = customerDetails.creditScoreRequests?.map(request => ({
            ...request,
            formattedRequestDate: new Date(request.Requested_Date__c).toLocaleDateString(),
            statusClass: this.getRequestStatusClass(request.Request_Status__c),
            handleRequestClick: () => this.navigateToRequest(request.Id)
        })) || [];

        // Process billing records
        this.recentBillingRecords = customerDetails.billingRecords?.map(billing => ({
            ...billing,
            formattedDueDate: billing.Bill_Due_Date__c ? 
                new Date(billing.Bill_Due_Date__c).toLocaleDateString() : 'N/A',
            formattedPaymentDate: billing.Bill_Payment_Date__c ? 
                new Date(billing.Bill_Payment_Date__c).toLocaleDateString() : 'Not Paid',
            paymentStatusText: billing.Is_Paid_On_Time__c ? 'On Time' : 'Late/Unpaid',
            paymentStatusClass: billing.Is_Paid_On_Time__c ? 'slds-badge slds-badge_success' : 'slds-badge slds-badge_error',
            formattedAmount: this.formatCurrency(billing.Bill_Amount__c)
        })) || [];

        console.log('Processed related lists:', {
            cases: this.recentCases.length,
            creditRequests: this.recentCreditRequests.length,
            billingRecords: this.recentBillingRecords.length
        });
    }

    formatCurrency(amount) {
        if (!amount) return '$0.00';
        try {
            return new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD'
            }).format(amount);
        } catch (error) {
            return '$' + amount;
        }
    }

    // Handle case row click
    handleCaseRowClick(event) {
        const caseId = event.currentTarget.dataset.caseId;
        if (caseId) {
            this.navigateToCase(caseId);
        }
    }

    // Navigation methods for related records
    navigateToCase(caseId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    navigateToRequest(requestId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: requestId,
                objectApiName: 'Credit_Score_Request__c',
                actionName: 'view'
            }
        });
    }

    // Handle view credit requests navigation
    handleViewCreditRequests() {
        const recordId = this.effectiveRecordId;
        if (!recordId) {
            this.showToast('Error', 'No account ID available', 'error');
            return;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId,
                objectApiName: 'Account',
                relationshipApiName: 'Credit_Score_Requests__r',
                actionName: 'view'
            }
        });
    }

    // Status class helpers
    getCaseStatusClass(status) {
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

    getCasePriorityClass(priority) {
        switch (priority?.toLowerCase()) {
            case 'high':
                return 'slds-badge slds-theme_error';
            case 'medium':
                return 'slds-badge slds-theme_warning';
            case 'low':
                return 'slds-badge slds-theme_success';
            default:
                return 'slds-badge';
        }
    }

    getRequestStatusClass(status) {
        switch (status?.toLowerCase()) {
            case 'pending':
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

    // Handle errors
    get hasError() {
        return this.error;
    }

    get errorMessage() {
        return this.error?.body?.message || this.error?.message || 'An error occurred loading customer details';
    }
}