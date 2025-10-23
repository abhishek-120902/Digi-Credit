//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import searchCustomers from '@salesforce/apex/CreditScoreCalculationService.searchCustomers';
import getCreditScoreRequests from '@salesforce/apex/CreditScoreCalculationService.getCreditScoreRequests';
import getBillingHistory from '@salesforce/apex/BillingDataIntegrationService.getBillingRecords';
import calculateCreditScore from '@salesforce/apex/CreditScoreCalculationService.calculateCreditScore';
import createCreditScoreRequest from '@salesforce/apex/CreditScoreCalculationService.createCreditScoreRequest';
import getCreditScoreHistory from '@salesforce/apex/CreditScoreCalculationService.getCreditScoreHistory';
import bulkRecalculateScores from '@salesforce/apex/CreditScoreCalculationService.bulkRecalculateScores';

export default class AgentTools extends NavigationMixin(LightningElement) {
    @api toolsTitle = 'Agent Tools';
    
    @track activeTab = 'search';
    @track isLoading = false;
    @track searchTerm = '';
    @track selectedCustomerId = null;
    @track selectedCustomer = null;
    @track customerResults = [];
    @track creditScoreRequests = [];
    @track billingHistory = [];
    @track creditScoreHistory = [];
    @track bulkAccountIds = '';
    @track isBulkProcessing = false;
    @track isRecalculating = false;
    @track isCreatingRequest = false;
    @track showCustomerDetails = false;
    @track error;

    // Tab management
    get tabClasses() {
        return {
            search: `slds-tabs_default__item ${this.activeTab === 'search' ? 'slds-is-active' : ''}`,
            requests: `slds-tabs_default__item ${this.activeTab === 'requests' ? 'slds-is-active' : ''}`,
            bulk: `slds-tabs_default__item ${this.activeTab === 'bulk' ? 'slds-is-active' : ''}`
        };
    }

    get isSearchTab() {
        return this.activeTab === 'search';
    }

    get isRequestsTab() {
        return this.activeTab === 'requests';
    }

    get isBulkTab() {
        return this.activeTab === 'bulk';
    }

    get hasSearchResults() {
        return this.customerResults && this.customerResults.length > 0;
    }

    get hasSelectedCustomer() {
        return this.selectedCustomer != null;
    }

    get hasCreditScoreRequests() {
        return this.creditScoreRequests && this.creditScoreRequests.length > 0;
    }

    get hasBillingHistory() {
        return this.billingHistory && this.billingHistory.length > 0;
    }

    get hasCreditScoreHistory() {
        return this.creditScoreHistory && this.creditScoreHistory.length > 0;
    }

    get customerDisplayName() {
        return this.selectedCustomer?.Name || 'Unknown Customer';
    }

    get customerCurrentScore() {
        return this.selectedCustomer?.Current_Credit_Score__c || 'No Score';
    }

    get customerEmail() {
        return this.selectedCustomer?.Email__c || 'No Email';
    }

    get customerPhone() {
        return this.selectedCustomer?.Phone || 'No Phone';
    }

    // Wire all credit score requests for agents
    @wire(getCreditScoreRequests, { accountId: null })
    wiredAllRequests(result) {
        this.wiredRequestsResult = result;
        if (result.data) {
            this.creditScoreRequests = result.data.map(request => ({
                ...request,
                formattedRequestDate: this.formatDateTime(request.Requested_Date__c),
                formattedCompletedDate: this.formatDateTime(request.Completed_Date__c),
                statusClass: this.getRequestStatusClass(request.Request_Status__c),
                customerName: request.Customer__r?.Name || 'Unknown'
            }));
        } else if (result.error) {
            this.showErrorToast('Error loading requests', result.error.body?.message || result.error.message);
        }
    }

    // Tab navigation
    handleTabClick(event) {
        this.activeTab = event.target.dataset.tab;
        this.clearSelection();
    }

    // Customer search functionality
    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    async handleSearch() {
        if (!this.searchTerm || this.searchTerm.length < 2) {
            this.showErrorToast('Search Error', 'Please enter at least 2 characters to search');
            return;
        }

        this.isLoading = true;
        try {
            const results = await searchCustomers({ searchTerm: this.searchTerm });
            this.customerResults = results.map(customer => ({
                ...customer,
                displayInfo: `${customer.Name} - ${customer.Email__c || customer.Phone || 'No Contact'}`
            }));
            
            if (this.customerResults.length === 0) {
                this.showInfoToast('No Results', 'No customers found matching your search criteria');
            }
        } catch (error) {
            this.showErrorToast('Search Failed', error.body?.message || error.message);
            this.customerResults = [];
        } finally {
            this.isLoading = false;
        }
    }

    // Customer selection
    async handleCustomerSelect(event) {
        const customerId = event.target.dataset.id;
        this.selectedCustomerId = customerId;
        this.selectedCustomer = this.customerResults.find(customer => customer.Id === customerId);
        this.showCustomerDetails = true;

        // Load customer details
        await this.loadCustomerDetails(customerId);
    }

    async loadCustomerDetails(customerId) {
        this.isLoading = true;
        try {
            // Load billing history
            const billingData = await getBillingHistory({ accountId: customerId });
            this.billingHistory = billingData.map(record => ({
                ...record,
                formattedDueDate: this.formatDate(record.Bill_Due_Date__c),
                formattedPaymentDate: this.formatDate(record.Bill_Payment_Date__c),
                statusClass: this.getBillingStatusClass(record.Payment_Status__c),
                formattedAmount: this.formatCurrency(record.Bill_Amount__c)
            }));

            // Load credit score history
            const scoreHistory = await getCreditScoreHistory({ accountId: customerId, limitRecords: 10 });
            this.creditScoreHistory = scoreHistory.map(score => ({
                ...score,
                formattedCalculationDate: this.formatDateTime(score.Calculation_Date__c),
                statusClass: this.getScoreStatusClass(score.Score_Status__c)
            }));

        } catch (error) {
            this.showErrorToast('Error Loading Details', error.body?.message || error.message);
        } finally {
            this.isLoading = false;
        }
    }

    // Credit score actions
    async handleRecalculateScore() {
        if (!this.selectedCustomerId) return;

        this.isRecalculating = true;
        try {
            await calculateCreditScore({ accountId: this.selectedCustomerId });
            
            // Reload customer details
            await this.loadCustomerDetails(this.selectedCustomerId);
            
            this.showSuccessToast('Score Recalculated', 'Credit score has been successfully recalculated');
        } catch (error) {
            this.showErrorToast('Recalculation Failed', error.body?.message || error.message);
        } finally {
            this.isRecalculating = false;
        }
    }

    async handleCreateRequest() {
        if (!this.selectedCustomerId) return;

        this.isCreatingRequest = true;
        try {
            await createCreditScoreRequest({ 
                accountId: this.selectedCustomerId,
                requestChannel: 'Agent'
            });
            
            // Refresh requests data
            await refreshApex(this.wiredRequestsResult);
            
            this.showSuccessToast('Request Created', 'Credit score request has been created successfully');
        } catch (error) {
            this.showErrorToast('Request Failed', error.body?.message || error.message);
        } finally {
            this.isCreatingRequest = false;
        }
    }

    // Navigation actions
    handleViewCustomerRecord() {
        if (!this.selectedCustomerId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedCustomerId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    handleViewBillingRecord(event) {
        const billingId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: billingId,
                objectApiName: 'Billing_Record__c',
                actionName: 'view'
            }
        });
    }

    handleViewRequest(event) {
        const requestId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: requestId,
                objectApiName: 'Credit_Score_Request__c',
                actionName: 'view'
            }
        });
    }

    // Bulk operations
    handleBulkAccountIdsChange(event) {
        this.bulkAccountIds = event.target.value;
    }

    async handleBulkRecalculate() {
        if (!this.bulkAccountIds.trim()) {
            this.showErrorToast('Input Required', 'Please enter Account IDs for bulk processing');
            return;
        }

        // Parse account IDs
        const accountIds = this.bulkAccountIds
            .split(/[,\n\r]/)
            .map(id => id.trim())
            .filter(id => id.length > 0);

        if (accountIds.length === 0) {
            this.showErrorToast('Invalid Input', 'No valid Account IDs found');
            return;
        }

        if (accountIds.length > 50) {
            this.showErrorToast('Too Many Records', 'Maximum 50 accounts can be processed at once');
            return;
        }

        this.isBulkProcessing = true;
        try {
            await bulkRecalculateScores({ accountIds: accountIds });
            
            this.showSuccessToast('Bulk Processing Started', 
                `Credit score recalculation started for ${accountIds.length} accounts. Processing will complete asynchronously.`);
            
            // Clear the input
            this.bulkAccountIds = '';
            
        } catch (error) {
            this.showErrorToast('Bulk Processing Failed', error.body?.message || error.message);
        } finally {
            this.isBulkProcessing = false;
        }
    }

    // Utility methods
    clearSelection() {
        this.selectedCustomerId = null;
        this.selectedCustomer = null;
        this.showCustomerDetails = false;
        this.billingHistory = [];
        this.creditScoreHistory = [];
    }

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

    getScoreStatusClass(status) {
        switch (status) {
            case 'Excellent':
                return 'slds-badge slds-theme_success';
            case 'Good':
                return 'slds-badge slds-theme_warning';
            case 'Poor':
                return 'slds-badge slds-theme_error';
            default:
                return 'slds-badge';
        }
    }

    // Toast utilities
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
