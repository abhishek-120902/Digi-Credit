trigger CreditScoreRequestTrigger on Credit_Score_Request__c (after insert, after update) {
    new CreditScoreRequestTriggerHandler().run();
}