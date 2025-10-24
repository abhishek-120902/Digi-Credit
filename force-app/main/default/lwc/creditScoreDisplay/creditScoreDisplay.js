import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import calculateCreditScore from '@salesforce/apex/CreditScoreCalculationService.calculateCreditScore';
import getCreditScoreHistory from '@salesforce/apex/CreditScoreCalculationService.getCreditScoreHistory';

// Account fields
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import ACCOUNT_CURRENT_SCORE_FIELD from '@salesforce/schema/Account.Current_Credit_Score__c';
import ACCOUNT_LAST_CALCULATION_FIELD from '@salesforce/schema/Account.Last_Score_Calculation__c';

// Credit Score fields
import CREDIT_SCORE_TOTAL_FIELD from '@salesforce/schema/Credit_Score__c.Total_Score__c';
import CREDIT_SCORE_STATUS_FIELD from '@salesforce/schema/Credit_Score__c.Score_Status__c';
import CREDIT_SCORE_COLOR_FIELD from '@salesforce/schema/Credit_Score__c.Score_Color__c';
import CREDIT_SCORE_BASE_FIELD from '@salesforce/schema/Credit_Score__c.Base_Score__c';
import CREDIT_SCORE_INTERNAL_FIELD from '@salesforce/schema/Credit_Score__c.Internal_Fields_Score__c';
import CREDIT_SCORE_BILLING_FIELD from '@salesforce/schema/Credit_Score__c.External_Billing_Score__c';
import CREDIT_SCORE_API_FIELD from '@salesforce/schema/Credit_Score__c.API_Score__c';
import CREDIT_SCORE_MISSING_FIELDS from '@salesforce/schema/Credit_Score__c.Missing_Fields__c';
import CREDIT_SCORE_CALCULATION_DATE from '@salesforce/schema/Credit_Score__c.Calculation_Date__c';

const ACCOUNT_FIELDS = [
    ACCOUNT_NAME_FIELD,
    ACCOUNT_CURRENT_SCORE_FIELD,
    ACCOUNT_LAST_CALCULATION_FIELD
];

export default class CreditScoreDisplay extends NavigationMixin(LightningElement) {
    @api recordId; // Account ID
    @api showRecalculateButton = false; // For agent use
    @api showHistory = false; // Fixed: Boolean public property must default to false
    @api cardTitle = 'Credit Score';
    
    @track isLoading = false;
    @track isRecalculating = false;
    @track showHistoryModal = false;
    @track creditScoreHistory = [];
    @track error;

    // Wire account data
    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    account;

    // Wire current credit score
    @wire(getCreditScoreHistory, { accountId: '$recordId', limitRecords: 1 })
    wiredCreditScore(result) {
        this.wiredCreditScoreResult = result;
        if (result.error) {
            this.error = result.error;
            this.showErrorToast('Error loading credit score', result.error.body?.message || result.error.message);
        }
    }

    get accountName() {
        return getFieldValue(this.account.data, ACCOUNT_NAME_FIELD);
    }

    get currentScore() {
        return getFieldValue(this.account.data, ACCOUNT_CURRENT_SCORE_FIELD);
    }

    get lastCalculationDate() {
        const date = getFieldValue(this.account.data, ACCOUNT_LAST_CALCULATION_FIELD);
        return date ? new Date(date).toLocaleDateString() : 'Never calculated';
    }

    get currentCreditScore() {
        return this.wiredCreditScoreResult?.data?.[0];
    }

    get hasCurrentScore() {
        return this.currentCreditScore != null;
    }

    get totalScore() {
        return this.currentCreditScore?.Total_Score__c || 0;
    }

    get scoreStatus() {
        return this.currentCreditScore?.Score_Status__c || 'Unknown';
    }

    get scoreColor() {
        return this.currentCreditScore?.Score_Color__c || 'Gray';
    }

    get baseScore() {
        return this.currentCreditScore?.Base_Score__c || 0;
    }

    get internalFieldsScore() {
        return this.currentCreditScore?.Internal_Fields_Score__c || 0;
    }

    get billingScore() {
        return this.currentCreditScore?.External_Billing_Score__c || 0;
    }

    get apiScore() {
        return this.currentCreditScore?.API_Score__c || 0;
    }

    get missingFields() {
        const fields = this.currentCreditScore?.Missing_Fields__c;
        return fields ? fields.split(', ') : [];
    }

    get calculationDate() {
        const date = this.currentCreditScore?.Calculation_Date__c;
        return date ? new Date(date).toLocaleDateString() : '';
    }

    get scoreColorClass() {
        const color = this.scoreColor.toLowerCase();
        return `score-circle score-${color}`;
    }

    get scoreStatusClass() {
        const status = this.scoreStatus.toLowerCase();
        return `score-status status-${status}`;
    }

    get progressBarClass() {
        const color = this.scoreColor.toLowerCase();
        return `slds-progress-bar__value score-progress-${color}`;
    }

    get scorePercentage() {
        // Calculate percentage based on 300-850 range
        const minScore = 300;
        const maxScore = 850;
        const percentage = ((this.totalScore - minScore) / (maxScore - minScore)) * 100;
        return Math.max(0, Math.min(100, Math.round(percentage)));
    }

    // Gauge-specific getters
    get gaugeColor() {
        const color = this.scoreColor.toLowerCase();
        switch (color) {
            case 'green':
                return '#28a745'; // Success green
            case 'yellow':
                return '#ffc107'; // Warning yellow
            case 'red':
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

    get missingFieldsList() {
        return this.missingFields;
    }

    get hasScoreHistory() {
        return this.creditScoreHistory && this.creditScoreHistory.length > 0;
    }

    get scoreHistory() {
        if (!this.creditScoreHistory) return [];
        
        return this.creditScoreHistory.map((score, index) => {
            const previousScore = index < this.creditScoreHistory.length - 1 ? 
                                 this.creditScoreHistory[index + 1] : null;
            
            let changeText = '';
            let changeIcon = '';
            let changeClass = '';
            let hasChange = false;
            
            if (previousScore && previousScore.Total_Score__c) {
                const change = score.Total_Score__c - previousScore.Total_Score__c;
                if (change > 0) {
                    changeText = `+${change}`;
                    changeIcon = 'utility:arrowup';
                    changeClass = 'slds-text-color_success';
                    hasChange = true;
                } else if (change < 0) {
                    changeText = `${change}`;
                    changeIcon = 'utility:arrowdown';
                    changeClass = 'slds-text-color_error';
                    hasChange = true;
                }
            }
            
            return {
                ...score,
                formattedDate: new Date(score.Calculation_Date__c).toLocaleDateString(),
                statusClass: this.getScoreStatusClass(score.Score_Status__c),
                changeText,
                changeIcon,
                changeClass,
                hasChange
            };
        });
    }

    getScoreStatusClass(status) {
        const statusLower = status ? status.toLowerCase() : '';
        switch (statusLower) {
            case 'excellent':
                return 'slds-badge slds-theme_success';
            case 'good':
                return 'slds-badge slds-theme_warning';
            case 'poor':
                return 'slds-badge slds-theme_error';
            default:
                return 'slds-badge';
        }
    }

    get hasMissingFields() {
        return this.missingFields.length > 0;
    }

    get showNoScoreMessage() {
        return !this.hasCurrentScore && !this.isLoading;
    }

    get isRequestingScore() {
        return this.isRecalculating;
    }

    // Handle recalculate button click
    async handleRecalculate() {
        if (!this.recordId) return;

        this.isRecalculating = true;
        try {
            await calculateCreditScore({ accountId: this.recordId });
            
            // Refresh the wired data
            await refreshApex(this.wiredCreditScoreResult);
            await refreshApex(this.account);

            this.showSuccessToast('Credit Score Recalculated', 'The credit score has been successfully recalculated.');
        } catch (error) {
            this.showErrorToast('Recalculation Failed', error.body?.message || error.message);
        } finally {
            this.isRecalculating = false;
        }
    }

    // Handle view history button click
    async handleViewHistory() {
        this.isLoading = true;
        try {
            const result = await getCreditScoreHistory({ accountId: this.recordId, limitRecords: 10 });
            this.creditScoreHistory = result || [];
            this.showHistoryModal = true;
        } catch (error) {
            this.showErrorToast('Error Loading History', error.body?.message || error.message);
        } finally {
            this.isLoading = false;
        }
    }

    // Close history modal
    handleCloseHistory() {
        this.showHistoryModal = false;
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

    handleNavigateToProfile() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/my-profile'
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

    handleUpdateProfile() {
        this.handleNavigateToProfile();
    }

    handleRequestScore() {
        this.handleNavigateToRequestScore();
    }

    // Utility methods for toast messages
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