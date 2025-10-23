//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

trigger BillingRecordTrigger on Billing_Record__c (after insert, after update, after delete) {
    new BillingRecordTriggerHandler().run();
}

//__________________________GenAI: Generated code ends here______________________________
