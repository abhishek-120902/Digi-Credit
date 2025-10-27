import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

// Import Apex methods
import getCustomerDetails from '@salesforce/apex/AgentService.getCustomerDetails';
import getRecentCases from '@salesforce/apex/AgentService.getRecentCases';
import getCreditScoreHistory from '@salesforce/apex/AgentService.getCreditScoreHistory';
import getRecentBillingRecords from '@salesforce/apex/AgentService.getRecentBillingRecords';

export default class AccountRelatedList extends NavigationMixin(LightningElement) {
    @api recordId; // Account ID passed from parent component or record page
    @api showCases = false;
    @api showCreditScores = false;
    @api showBillingRecords = false;
    @api maxRecords = 5;
    @track currentRecordId;

    @track recentCases = [];
    @track creditScoreHistory = [];
    @track recentBillingRecords = [];
    
    @track casesLoading = false;
    @track creditScoresLoading = false;
    @track billingLoading = false;
    @track isLoading = false;
    
    @track casesError = null;
    @track creditScoresError = null;
    @track billingError = null;
    
    // Store wire results for refresh
    casesWireResult;
    creditScoresWireResult;
    billingWireResult;
    
    // Customer details wrapper
    @track customerDetailsWrapper;

    // Wire current page reference to get URL parameters
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            console.log('AccountRelatedList - Current Page Reference:', JSON.stringify(currentPageReference, null, 2));
            
            // Get recordId from URL parameters if not provided via @api
            if (!this.recordId) {
                // Check URL state parameters
                this.currentRecordId = currentPageReference.state?.recordId || 
                                     currentPageReference.attributes?.recordId ||
                                     this.extractRecordIdFromUrl(currentPageReference);
                console.log('AccountRelatedList - Resolved currentRecordId:', this.currentRecordId);
            } else {
                this.currentRecordId = this.recordId;
                console.log('AccountRelatedList - Using @api recordId:', this.recordId);
            }
        }
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
                console.log('AccountRelatedList - URL Path for record extraction:', urlPath);
                
                // Try different patterns for record ID extraction
                // Pattern 1: /account/{recordId}/detail or /account/{recordId}
                let recordIdMatch = urlPath.match(/\/account\/([a-zA-Z0-9]{15,18})/);
                if (recordIdMatch) {
                    console.log('AccountRelatedList - Found record ID from account pattern:', recordIdMatch[1]);
                    return recordIdMatch[1];
                }
                
                // Pattern 2: /customer/{recordId}/detail or /customer/{recordId}
                recordIdMatch = urlPath.match(/\/customer\/([a-zA-Z0-9]{15,18})/);
                if (recordIdMatch) {
                    console.log('AccountRelatedList - Found record ID from customer pattern:', recordIdMatch[1]);
                    return recordIdMatch[1];
                }
                
                // Pattern 3: Any 15-18 character Salesforce ID in the URL
                recordIdMatch = urlPath.match(/([a-zA-Z0-9]{15,18})/);
                if (recordIdMatch) {
                    console.log('AccountRelatedList - Found record ID from general pattern:', recordIdMatch[1]);
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
                console.log('AccountRelatedList - Found record ID from state:', stateRecordId);
                return stateRecordId;
            }
        }
        
        // Last resort: try to get from browser URL
        try {
            const currentUrl = window.location.href;
            console.log('AccountRelatedList - Current URL:', currentUrl);
            const urlRecordMatch = currentUrl.match(/\/account\/([a-zA-Z0-9]{15,18})/);
            if (urlRecordMatch) {
                console.log('AccountRelatedList - Found record ID from browser URL:', urlRecordMatch[1]);
                return urlRecordMatch[1];
            }
        } catch (error) {
            console.error('AccountRelatedList - Error extracting from browser URL:', error);
        }
        
        console.log('AccountRelatedList - No record ID found in URL');
        return null;
    }

    // Get the effective recordId (from @api or URL)
    get effectiveRecordId() {
        const effectiveId = this.recordId || this.currentRecordId;
        console.log('AccountRelatedList - Effective Record ID:', effectiveId, 'recordId:', this.recordId, 'currentRecordId:', this.currentRecordId);
        return effectiveId;
    }

    // Load customer details using single Apex method (like customerDetailView)
    loadCustomerDetails() {
        const accountId = this.effectiveRecordId;
        if (!accountId) {
            console.log('AccountRelatedList - No account ID available for loading customer details');
            return;
        }

        console.log('AccountRelatedList - Loading customer details for account ID:', accountId);
        this.isLoading = true;
        this.casesError = null;
        this.creditScoresError = null;
        this.billingError = null;

        getCustomerDetails({ accountId })
            .then(result => {
                console.log('AccountRelatedList - Customer details loaded successfully:', result);
                this.customerDetailsWrapper = result;

                // Process related lists like customerDetailView does
                this.processRelatedLists(result);
            })
            .catch(error => {
                console.error('AccountRelatedList - Error loading customer details:', error);
                this.casesError = error;
                this.creditScoresError = error;
                this.billingError = error;
                this.showToast('Error', 'Failed to load customer details: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Process related lists from customer details wrapper (same as customerDetailView)
    processRelatedLists(customerDetails) {

        if(customerDetails.cases) this.showCases = true;
        if(customerDetails.creditScores) this.showCreditScores = true;
        if(customerDetails.billingRecords) this.showBillingRecords = true;

        // Process cases
        if (this.showCases) {
            this.recentCases = customerDetails.cases?.slice(0, this.maxRecords).map((caseRecord, index) => ({
                ...caseRecord,
                formattedCreatedDate: this.formatDate(caseRecord.CreatedDate),
                statusClass: this.getCaseStatusClass(caseRecord.Status),
                priorityClass: this.getCasePriorityClass(caseRecord.Priority),
                index: index
            })) || [];
            console.log('AccountRelatedList - Processed cases:', this.recentCases.length);
        }

        // Process credit score history
        if (this.showCreditScores) {
            this.creditScoreHistory = customerDetails.creditScores?.slice(0, this.maxRecords).map(score => ({
                ...score,
                formattedDate: this.formatDate(score.Calculation_Date__c),
                statusClass: this.getScoreStatusClass(score.Score_Status__c),
                scoreChange: this.calculateScoreChange(score, customerDetails.creditScores)
            })) || [];
            console.log('AccountRelatedList - Processed credit scores:', this.creditScoreHistory.length);
        }

        // Process billing records
        if (this.showBillingRecords) {
            this.recentBillingRecords = customerDetails.billingRecords?.slice(0, this.maxRecords).map(billing => ({
                ...billing,
                formattedDueDate: this.formatDate(billing.Bill_Due_Date__c),
                formattedPaymentDate: this.formatDate(billing.Bill_Payment_Date__c),
                paymentStatusText: billing.Is_Paid_On_Time__c ? 'On Time' : 'Late/Unpaid',
                paymentStatusClass: billing.Is_Paid_On_Time__c ? 
                    'slds-badge slds-badge_success' : 'slds-badge slds-badge_error',
                formattedAmount: this.formatCurrency(billing.Bill_Amount__c)
            })) || [];
            console.log('AccountRelatedList - Processed billing records:', this.recentBillingRecords.length);
        }

        console.log('AccountRelatedList - Processed related lists:', {
            cases: this.recentCases.length,
            creditScores: this.creditScoreHistory.length,
            billingRecords: this.recentBillingRecords.length
        });
    }

    // Getters for conditional rendering
    get hasCases() {
        return this.showCases && this.recentCases && this.recentCases.length > 0;
    }

    get hasCreditScores() {
        return this.showCreditScores && this.creditScoreHistory && this.creditScoreHistory.length > 0;
    }

    get hasBillingRecords() {
        return this.showBillingRecords && this.recentBillingRecords && this.recentBillingRecords.length > 0;
    }

    get noCasesMessage() {
        return this.casesError ? 
            'Error loading cases: ' + this.getErrorMessage(this.casesError) :
            'No cases assigned to you for this customer.';
    }

    get noCreditScoresMessage() {
        return this.creditScoresError ? 
            'Error loading credit scores: ' + this.getErrorMessage(this.creditScoresError) :
            'No credit score history found for this customer.';
    }

    get noBillingMessage() {
        return this.billingError ? 
            'Error loading billing records: ' + this.getErrorMessage(this.billingError) :
            'No billing records found for this customer.';
    }

    // Event Handlers
    handleCaseRowClick(event) {
        const caseId = event.currentTarget.dataset.caseId;
        if (caseId) {
            this.navigateToRecord(caseId, 'Case');
        }
    }

    handleCreditScoreRowClick(event) {
        const scoreId = event.currentTarget.dataset.scoreId;
        if (scoreId) {
            this.navigateToRecord(scoreId, 'Credit_Score__c');
        }
    }

    handleBillingRowClick(event) {
        const billingId = event.currentTarget.dataset.billingId;
        if (billingId) {
            this.navigateToRecord(billingId, 'Billing_Record__c');
        }
    }

    handleViewAllCases() {
        this.navigateToRelatedList('Cases');
    }

    handleViewAllCreditScores() {
        this.navigateToRelatedList('Credit_Scores__r');
    }

    handleViewAllBillingRecords() {
        this.navigateToRelatedList('Billing_Records__r');
    }

    handleRefresh() {
        // Refresh by reloading customer details (like customerDetailView)
        this.loadCustomerDetails();
        this.showToast('Success', 'Related lists refreshed', 'success');
    }

    // Navigation Methods
    navigateToRecord(recordId, objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                actionName: 'view'
            }
        });
    }

    navigateToRelatedList(relationshipApiName) {
        const recordId = this.effectiveRecordId;
        if (!recordId) {
            this.showToast('Error', 'No account ID available', 'error');
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Account',
                relationshipApiName: relationshipApiName,
                actionName: 'view'
            }
        });
    }

    // Utility Methods
    formatDate(dateValue) {
        if (!dateValue) return 'N/A';
        try {
            return new Date(dateValue).toLocaleDateString();
        } catch (error) {
            return 'Invalid Date';
        }
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

    getScoreStatusClass(status) {
        switch (status?.toLowerCase()) {
            case 'excellent':
                return 'score-excellent';
            case 'good':
                return 'score-good';
            case 'poor':
                return 'score-poor';
            default:
                return 'score-unknown';
        }
    }

    calculateScoreChange(currentScore, allScores) {
        if (!allScores || allScores.length < 2) return null;
        
        const currentIndex = allScores.findIndex(score => score.Id === currentScore.Id);
        if (currentIndex === -1 || currentIndex === allScores.length - 1) return null;
        
        const previousScore = allScores[currentIndex + 1];
        const change = currentScore.Total_Score__c - previousScore.Total_Score__c;
        
        return {
            value: change,
            isPositive: change > 0,
            isNegative: change < 0,
            displayValue: change > 0 ? `+${change}` : change.toString()
        };
    }

    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return 'Unknown error occurred';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    // Lifecycle Methods
    connectedCallback() {
        const recordId = this.effectiveRecordId;
        if (!recordId) {
            console.warn('AccountRelatedList: No recordId provided or found in URL');
        } else {
            console.log('AccountRelatedList: Using recordId:', recordId);
            // Load customer details when component is connected (like customerDetailView)
            this.loadCustomerDetails();
        }
    }

    // Watch for recordId changes and reload data
    @api
    refreshData() {
        this.loadCustomerDetails();
    }
}
