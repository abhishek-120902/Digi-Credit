declare module "@salesforce/apex/SupportCaseService.getCaseHistory" {
  export default function getCaseHistory(param: {accountId: any}): Promise<any>;
}
declare module "@salesforce/apex/SupportCaseService.createSupportCase" {
  export default function createSupportCase(param: {accountId: any, subject: any, description: any, priority: any}): Promise<any>;
}
declare module "@salesforce/apex/SupportCaseService.updateCaseStatus" {
  export default function updateCaseStatus(param: {caseId: any, newStatus: any}): Promise<any>;
}
declare module "@salesforce/apex/SupportCaseService.getCaseDetails" {
  export default function getCaseDetails(param: {caseId: any}): Promise<any>;
}
declare module "@salesforce/apex/SupportCaseService.getCasesByStatus" {
  export default function getCasesByStatus(param: {accountId: any, status: any}): Promise<any>;
}
declare module "@salesforce/apex/SupportCaseService.addCaseComment" {
  export default function addCaseComment(param: {caseId: any, commentBody: any}): Promise<any>;
}
declare module "@salesforce/apex/SupportCaseService.getCaseComments" {
  export default function getCaseComments(param: {caseId: any}): Promise<any>;
}
declare module "@salesforce/apex/SupportCaseService.getCaseStatistics" {
  export default function getCaseStatistics(param: {accountId: any}): Promise<any>;
}
