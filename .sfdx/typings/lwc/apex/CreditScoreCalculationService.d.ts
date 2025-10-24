declare module "@salesforce/apex/CreditScoreCalculationService.calculateCreditScore" {
  export default function calculateCreditScore(param: {accountId: any}): Promise<any>;
}
declare module "@salesforce/apex/CreditScoreCalculationService.getCreditScoreRequests" {
  export default function getCreditScoreRequests(param: {accountId: any}): Promise<any>;
}
declare module "@salesforce/apex/CreditScoreCalculationService.createCreditScoreRequest" {
  export default function createCreditScoreRequest(param: {accountId: any, requestChannel: any, processingNotes: any}): Promise<any>;
}
declare module "@salesforce/apex/CreditScoreCalculationService.getCreditScoreHistory" {
  export default function getCreditScoreHistory(param: {accountId: any, limitRecords: any}): Promise<any>;
}
declare module "@salesforce/apex/CreditScoreCalculationService.getCurrentUserAccount" {
  export default function getCurrentUserAccount(): Promise<any>;
}
declare module "@salesforce/apex/CreditScoreCalculationService.updateAccountProfile" {
  export default function updateAccountProfile(param: {accountId: any, profileData: any}): Promise<any>;
}
declare module "@salesforce/apex/CreditScoreCalculationService.searchCustomers" {
  export default function searchCustomers(param: {searchTerm: any}): Promise<any>;
}
declare module "@salesforce/apex/CreditScoreCalculationService.bulkRecalculateScores" {
  export default function bulkRecalculateScores(param: {accountIds: any}): Promise<any>;
}
declare module "@salesforce/apex/CreditScoreCalculationService.getSystemAnalytics" {
  export default function getSystemAnalytics(): Promise<any>;
}
