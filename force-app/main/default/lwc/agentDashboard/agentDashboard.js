import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getAgentDashboardStats from '@salesforce/apex/AgentService.getAgentDashboardStats';
import getAssignedCases from '@salesforce/apex/AgentService.getAssignedCases';
import getAllCustomers from '@salesforce/apex/AgentService.getAllCustomers';
import searchCases from '@salesforce/apex/AgentService.searchCases';
import updateCaseStatus from '@salesforce/apex/AgentService.updateCaseStatus';

export default class AgentDashboard extends NavigationMixin(LightningElement) {
    @api title = 'Agent Dashboard';
    @track dashboardStats = {};
    @track assignedCases = [];
    @track recentCustomers = [];
    @track isLoading = false;
    @track error;
    @track activeTab = 'overview';
    @track selectedCase = null;
    @track showCaseModal = false;
    @track caseUpdateNotes = '';
    @track caseUpdateStatus = '';
    @track searchTerm = '';
    @track statusFilter = '';
    @track priorityFilter = '';

    // Tab management
    get tabClasses() {
        return {
            overview: `slds-tabs_default__item ${this.activeTab === 'overview' ? 'slds-is-active' : ''}`,
            cases: `slds-tabs_default__item ${this.activeTab === 'cases' ? 'slds-is-active' : ''}`,
            customers: `slds-tabs_default__item ${this.activeTab === 'customers' ? 'slds-is-active' : ''}`
        };
    }

    get isOverviewTab() {
        return this.activeTab === 'overview';
    }

    get isCasesTab() {
        return this.activeTab === 'cases';
    }

    get isCustomersTab() {
        return this.activeTab === 'customers';
    }

    get hasAssignedCases() {
        return this.assignedCases && this.assignedCases.length > 0;
    }

    get hasRecentCustomers() {
        return this.recentCustomers && this.recentCustomers.length > 0;
    }

    get caseStatusOptions() {
        return [
            { label: 'All Statuses', value: '' },
            { label: 'New', value: 'New' },
            { label: 'Working', value: 'Working' },
            { label: 'Escalated', value: 'Escalated' },
            { label: 'Closed', value: 'Closed' }
        ];
    }

    get casePriorityOptions() {
        return [
            { label: 'All Priorities', value: '' },
            { label: 'High', value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low', value: 'Low' }
        ];
    }

    get caseUpdateStatusOptions() {
        return [
            { label: 'New', value: 'New' },
            { label: 'Working', value: 'Working' },
            { label: 'Escalated', value: 'Escalated' },
            { label: 'Closed', value: 'Closed' }
        ];
    }

    get caseColumns() {
        return [
            {
                label: 'Case Number',
                fieldName: 'CaseNumber',
                type: 'text',
                sortable: true
            },
            {
                label: 'Subject',
                fieldName: 'Subject',
                type: 'text',
                sortable: true
            },
            {
                label: 'Account',
                fieldName: 'accountName',
                type: 'text',
                sortable: true
            },
            {
                label: 'Status',
                fieldName: 'Status',
                type: 'text',
                sortable: true
            },
            {
                label: 'Priority',
                fieldName: 'Priority',
                type: 'text',
                sortable: true
            },
            {
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'View', name: 'view' },
                        { label: 'Edit', name: 'edit' }
                    ]
                }
            }
        ];
    }

    // Wire dashboard statistics
    @wire(getAgentDashboardStats)
    wiredDashboardStats(result) {
        this.wiredStatsResult = result;
        console.log('Dashboard Stats Wire Result:', result);
        
        if (result.data) {
            console.log('Dashboard Stats Data:', result.data);
            this.dashboardStats = result.data;
        } else if (result.error) {
            console.error('Dashboard Stats Error:', result.error);
            this.showErrorToast('Error loading dashboard stats', result.error.body?.message || result.error.message);
        }
    }

    // Wire assigned cases
    @wire(getAssignedCases)
    wiredAssignedCases(result) {
        this.wiredCasesResult = result;
        console.log('Cases Wire Result:', result);
        console.log('Cases Data:', result.data);
        console.log('Cases Data Type:', typeof result.data);
        console.log('Cases Data Length:', result.data ? result.data.length : 'No data');
        
        if (result.data && Array.isArray(result.data)) {
            console.log('Processing cases data:', result.data);
            this.assignedCases = result.data.map(caseRecord => ({
                ...caseRecord,
                formattedLastModifiedDate: this.formatDateTime(caseRecord.LastModifiedDate),
                statusClass: this.getCaseStatusClass(caseRecord.Status),
                priorityClass: this.getCasePriorityClass(caseRecord.Priority),
                accountName: caseRecord.Account?.Name || 'No Account'
            }));
            console.log('Processed cases:', this.assignedCases);
        } else if (result.error) {
            console.error('Cases Error:', result.error);
            this.showErrorToast('Error loading cases', result.error.body?.message || result.error.message);
        } else {
            console.log('No cases data or empty array');
            this.assignedCases = [];
        }
    }

    // Wire recent customers
    @wire(getAllCustomers, { limitRecords: 20 })
    wiredRecentCustomers(result) {
        this.wiredCustomersResult = result;
        console.log('Customers Wire Result:', result);
        console.log('Customers Data:', result.data);
        console.log('Customers Data Type:', typeof result.data);
        console.log('Customers Data Length:', result.data ? result.data.length : 'No data');
        console.log('Customers Data Array Check:', Array.isArray(result.data));
        
        if (result.data && Array.isArray(result.data)) {
            console.log('Processing customers data:', result.data);
            this.recentCustomers = result.data.map(customer => ({
                ...customer,
                formattedCreatedDate: this.formatDateTime(customer.CreatedDate),
                formattedLastCalculation: this.formatDateTime(customer.Last_Score_Calculation__c),
                scoreStatusClass: this.getScoreStatusClass(customer.Current_Credit_Score__c),
                displayScore: customer.Current_Credit_Score__c || 'No Score'
            }));
            console.log('Processed customers:', this.recentCustomers);
        } else if (result.error) {
            console.error('Customers Error:', result.error);
            this.showErrorToast('Error loading customers', result.error.body?.message || result.error.message);
        } else {
            console.log('No customers data or empty array');
            this.recentCustomers = [];
        }
    }

    // Tab navigation
    handleTabClick(event) {
        this.activeTab = event.target.dataset.tab;
    }

    // Case management
    handleCaseClick(event) {
        const caseId = event.target.dataset.id;
        this.selectedCase = this.assignedCases.find(c => c.Id === caseId);
        this.caseUpdateStatus = this.selectedCase.Status;
        this.caseUpdateNotes = '';
        this.showCaseModal = true;
    }

    handleCaseModalClose() {
        this.showCaseModal = false;
        this.selectedCase = null;
        this.caseUpdateNotes = '';
        this.caseUpdateStatus = '';
    }

    handleCaseStatusChange(event) {
        this.caseUpdateStatus = event.detail.value;
    }

    handleCaseNotesChange(event) {
        this.caseUpdateNotes = event.target.value;
    }

    async handleCaseUpdate() {
        if (!this.selectedCase) return;

        this.isLoading = true;
        try {
            await updateCaseStatus({
                caseId: this.selectedCase.Id,
                newStatus: this.caseUpdateStatus,
                notes: this.caseUpdateNotes
            });

            // Refresh cases data
            await refreshApex(this.wiredCasesResult);
            await refreshApex(this.wiredStatsResult);

            this.showSuccessToast('Case Updated', 'Case has been updated successfully');
            this.handleCaseModalClose();

        } catch (error) {
            this.showErrorToast('Update Failed', error.body?.message || error.message);
        } finally {
            this.isLoading = false;
        }
    }

    // Case search and filtering
    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.performCaseSearch();
    }

    handlePriorityFilterChange(event) {
        this.priorityFilter = event.detail.value;
        this.performCaseSearch();
    }

    async handleCaseSearch() {
        this.performCaseSearch();
    }

    async performCaseSearch() {
        this.isLoading = true;
        try {
            const results = await searchCases({
                searchTerm: this.searchTerm,
                status: this.statusFilter,
                priority: this.priorityFilter
            });

            console.log('Search results:', results);
            
            if (results && Array.isArray(results)) {
                this.assignedCases = results.map(caseRecord => ({
                    ...caseRecord,
                    formattedLastModifiedDate: this.formatDateTime(caseRecord.LastModifiedDate),
                    statusClass: this.getCaseStatusClass(caseRecord.Status),
                    priorityClass: this.getCasePriorityClass(caseRecord.Priority),
                    accountName: caseRecord.Account?.Name || 'No Account'
                }));
            } else {
                this.assignedCases = [];
            }

        } catch (error) {
            console.error('Search error:', error);
            this.showErrorToast('Search Failed', error.body?.message || error.message);
        } finally {
            this.isLoading = false;
        }
    }

    async handleClearSearch() {
        this.searchTerm = '';
        this.statusFilter = '';
        this.priorityFilter = '';

        this.handleCaseSearch();
        refreshApex(this.wiredCasesResult);
    }

    // Navigation methods
    handleViewCase(event) {
        const caseId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    handleViewCustomer(event) {
        const customerId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: customerId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    handleCreateCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'new'
            }
        });
    }

    // Handle datatable row actions
    handleCaseRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        switch (actionName) {
            case 'view':
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.Id,
                        objectApiName: 'Case',
                        actionName: 'view'
                    }
                });
                break;
            case 'edit':
                this.selectedCase = row;
                this.caseUpdateStatus = row.Status;
                this.caseUpdateNotes = '';
                this.showCaseModal = true;
                break;
            default:
                break;
        }
    }

    // Utility methods
    formatDateTime(dateTimeValue) {
        if (!dateTimeValue) return '';
        return new Date(dateTimeValue).toLocaleString();
    }

    getCaseStatusClass(status) {
        switch (status) {
            case 'Closed':
                return 'slds-badge slds-theme_success';
            case 'Working':
                return 'slds-badge slds-theme_info';
            case 'Escalated':
                return 'slds-badge slds-theme_error';
            case 'New':
                return 'slds-badge slds-theme_warning';
            default:
                return 'slds-badge';
        }
    }

    getCasePriorityClass(priority) {
        switch (priority) {
            case 'High':
                return 'slds-badge slds-theme_error';
            case 'Medium':
                return 'slds-badge slds-theme_warning';
            case 'Low':
                return 'slds-badge slds-theme_success';
            default:
                return 'slds-badge';
        }
    }

    getScoreStatusClass(score) {
        if (!score) return 'slds-badge';
        
        if (score >= 600) {
            return 'slds-badge slds-theme_success';
        } else if (score >= 450) {
            return 'slds-badge slds-theme_warning';
        } else {
            return 'slds-badge slds-theme_error';
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
