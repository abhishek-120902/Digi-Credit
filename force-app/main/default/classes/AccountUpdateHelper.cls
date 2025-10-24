/**
 * Helper class to update Account records without sharing restrictions
 * This allows community users to update their own Person Account records
 */
public without sharing class AccountUpdateHelper {
    
    /**
     * Update Account record bypassing sharing rules
     * @param accountToUpdate Account record to update
     */
    public static void updateAccount(Account accountToUpdate) {
        update accountToUpdate;
    }
    
    /**
     * Update multiple Account records bypassing sharing rules
     * @param accountsToUpdate List of Account records to update
     */
    public static void updateAccounts(List<Account> accountsToUpdate) {
        update accountsToUpdate;
    }
}