//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getSystemAnalytics from '@salesforce/apex/CreditScoreCalculationService.getSystemAnalytics';
import getCreditScoreConfiguration from '@salesforce/apex/CreditScoreConfigurationService.getActiveConfiguration';
import updateCreditScoreConfiguration from '@salesforce/apex/CreditScoreConfigurationService.updateConfiguration';
import bulkRecalculateScores from '@salesforce/apex/CreditScoreCalculationService.bulkRecalculateScores';

export default class ExecutiveAnalytics extends NavigationMixin(LightningElement) {
    @api analyticsTitle = 'Executive Analytics';
    
    @track activeTab = 'overview';
    @track isLoading = false;
    @track isSaving = false;
    @track isBulkProcessing = false;
    @track systemAnalytics = {};
    @track creditScoreConfig = [];
    @track editableConfig = [];
    @track isEditingConfig = false;
    @track error;

    // Chart data
    @track scoreDistributionData = [];
    @track requestTrendData = [];
    @track performanceMetrics = {};

    // Wire system analytics
    @wire(getSystemAnalytics)
    wiredAnalytics(result) {
        this.wiredAnalyticsResult = result;
        if (result.data) {
            this.systemAnalytics = result.data;
            this.processAnalyticsData(result.data);
        } else if (result.error) {
            this.showErrorToast('Error loading analytics', result.error.body?.message || result.error.message);
        }
    }

    // Wire credit score configuration
    @wire(getCreditScoreConfiguration)
    wiredConfiguration(result) {
        this.wiredConfigResult = result;
        if (result.data) {
            this.creditScoreConfig = result.data;
            this.initializeEditableConfig();
        } else if (result.error) {
            this.showErrorToast('Error loading configuration', result.error.body?.message || result.error.message);
        }
    }

    // Tab management
    get tabClasses() {
        return {
            overview: `slds-tabs_default__item ${this.activeTab === 'overview' ? 'slds-is-active' : ''}`,
            analytics: `slds-tabs_default__item ${this.activeTab === 'analytics' ? 'slds-is-active' : ''}`,
            configuration: `slds-tabs_default__item ${this.activeTab === 'configuration' ? 'slds-is-active' : ''}`,
            operations: `slds-tabs_default__item ${this.activeTab === 'operations' ? 'slds-is-active' : ''}`
        };
    }

    get isOverviewTab() {
        return this.activeTab === 'overview';
    }

    get isAnalyticsTab() {
        return this.activeTab === 'analytics';
    }

    get isConfigurationTab() {
        return this.activeTab === 'configuration';
    }

    get isOperationsTab() {
        return this.activeTab === 'operations';
    }

    // Analytics getters
    get totalCustomers() {
        return this.systemAnalytics.totalCustomers || 0;
    }

    get totalScoresCalculated() {
        return this.systemAnalytics.totalScoresCalculated || 0;
    }

    get averageCreditScore() {
        return this.systemAnalytics.averageCreditScore || 0;
    }

    get pendingRequests() {
        return this.systemAnalytics.pendingRequests || 0;
    }

    get completedRequestsToday() {
        return this.systemAnalytics.completedRequestsToday || 0;
    }

    get systemHealthScore() {
        return this.systemAnalytics.systemHealthScore || 0;
    }

    get poorScorePercentage() {
        return this.performanceMetrics.poorScorePercentage || 0;
    }

    get goodScorePercentage() {
        return this.performanceMetrics.goodScorePercentage || 0;
    }

    get excellentScorePercentage() {
        return this.performanceMetrics.excellentScorePercentage || 0;
    }

    get hasConfiguration() {
        return this.creditScoreConfig && this.creditScoreConfig.length > 0;
    }

    get hasAnalyticsData() {
        return Object.keys(this.systemAnalytics).length > 0;
    }

    // Process analytics data for charts
    processAnalyticsData(data) {
        // Process score distribution
        if (data.scoreDistribution) {
            this.scoreDistributionData = [
                { label: 'Poor (300-450)', value: data.scoreDistribution.poor || 0, color: '#c23934' },
                { label: 'Good (450-600)', value: data.scoreDistribution.good || 0, color: '#ffb75d' },
                { label: 'Excellent (600-750)', value: data.scoreDistribution.excellent || 0, color: '#4bca81' }
            ];
        }

        // Process performance metrics
        const total = (data.scoreDistribution?.poor || 0) + 
                     (data.scoreDistribution?.good || 0) + 
                     (data.scoreDistribution?.excellent || 0);
        
        if (total > 0) {
            this.performanceMetrics = {
                poorScorePercentage: Math.round(((data.scoreDistribution?.poor || 0) / total) * 100),
                goodScorePercentage: Math.round(((data.scoreDistribution?.good || 0) / total) * 100),
                excellentScorePercentage: Math.round(((data.scoreDistribution?.excellent || 0) / total) * 100)
            };
        }

        // Process request trends (last 7 days)
        if (data.requestTrends) {
            this.requestTrendData = data.requestTrends.map(trend => ({
                date: this.formatDate(trend.date),
                requests: trend.count || 0
            }));
        }
    }

    // Tab navigation
    handleTabClick(event) {
        this.activeTab = event.target.dataset.tab;
    }

    // Configuration management
    initializeEditableConfig() {
        this.editableConfig = this.creditScoreConfig.map(config => ({
            ...config,
            Weight__c: config.Weight__c || 0
        }));
    }

    handleEditConfiguration() {
        this.isEditingConfig = true;
    }

    handleCancelConfigEdit() {
        this.isEditingConfig = false;
        this.initializeEditableConfig();
    }

    handleConfigFieldChange(event) {
        const fieldName = event.target.dataset.field;
        const configId = event.target.dataset.id;
        const value = event.target.value;

        this.editableConfig = this.editableConfig.map(config => {
            if (config.Id === configId) {
                return { ...config, [fieldName]: value };
            }
            return config;
        });
    }

    async handleSaveConfiguration() {
        this.isSaving = true;
        try {
            await updateCreditScoreConfiguration({ configurations: this.editableConfig });
            
            // Refresh configuration data
            await refreshApex(this.wiredConfigResult);
            
            this.isEditingConfig = false;
            this.showSuccessToast('Configuration Updated', 'Credit score configuration has been successfully updated.');
        } catch (error) {
            this.showErrorToast('Update Failed', error.body?.message || error.message);
        } finally {
            this.isSaving = false;
        }
    }

    // System operations
    async handleRefreshAnalytics() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredAnalyticsResult);
            this.showSuccessToast('Analytics Refreshed', 'System analytics have been refreshed successfully.');
        } catch (error) {
            this.showErrorToast('Refresh Failed', error.body?.message || error.message);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSystemRecalculation() {
        // Confirm before proceeding
        const confirmed = await this.showConfirmDialog(
            'System-wide Recalculation',
            'This will recalculate credit scores for all customers. This operation may take several minutes. Continue?'
        );

        if (!confirmed) return;

        this.isBulkProcessing = true;
        try {
            // Get all account IDs (this would need to be implemented in the service)
            await bulkRecalculateScores({ accountIds: null }); // null means all accounts
            
            this.showSuccessToast('System Recalculation Started', 
                'System-wide credit score recalculation has been initiated. This will complete asynchronously.');
        } catch (error) {
            this.showErrorToast('Recalculation Failed', error.body?.message || error.message);
        } finally {
            this.isBulkProcessing = false;
        }
    }

    // Utility methods
    formatDate(dateValue) {
        if (!dateValue) return '';
        return new Date(dateValue).toLocaleDateString();
    }

    formatDateTime(dateTimeValue) {
        if (!dateTimeValue) return '';
        return new Date(dateTimeValue).toLocaleString();
    }

    formatNumber(number) {
        if (!number) return '0';
        return new Intl.NumberFormat().format(number);
    }

    formatPercentage(value) {
        return `${value}%`;
    }

    getHealthScoreClass() {
        const score = this.systemHealthScore;
        if (score >= 90) return 'health-excellent';
        if (score >= 70) return 'health-good';
        if (score >= 50) return 'health-warning';
        return 'health-poor';
    }

    getHealthScoreColor() {
        const score = this.systemHealthScore;
        if (score >= 90) return '#4bca81';
        if (score >= 70) return '#ffb75d';
        if (score >= 50) return '#ff9500';
        return '#c23934';
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

    handleNavigateToAgentTools() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/agent-tools'
            }
        });
    }

    handleNavigateToReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/reports'
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

    // Confirmation dialog (simplified - in real implementation, use lightning/confirm)
    async showConfirmDialog(title, message) {
        return confirm(`${title}\n\n${message}`);
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

    showWarningToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'warning'
        }));
    }
}

//__________________________GenAI: Generated code ends here______________________________
