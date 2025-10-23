//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

trigger AccountTrigger on Account (after insert, after update) {
    new AccountTriggerHandler().run();
}

//__________________________GenAI: Generated code ends here______________________________
