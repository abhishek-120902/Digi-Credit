//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public class CreditScoreEmailNotificationQueueable implements Queueable {
    
    private List<Account> accounts;
    private Map<Id, Credit_Score__c> creditScores;
    
    public CreditScoreEmailNotificationQueueable(List<Account> accounts, Map<Id, Credit_Score__c> creditScores) {
        this.accounts = accounts;
        this.creditScores = creditScores;
    }
    
    public void execute(QueueableContext context) {
        try {
            if (accounts == null || accounts.isEmpty()) {
                System.debug('CreditScoreEmailNotificationQueueable: No accounts provided');
                return;
            }
            
            System.debug('CreditScoreEmailNotificationQueueable: Processing notifications for ' + accounts.size() + ' accounts');
            
            // Send email notifications
            sendCreditScoreNotifications();
            
            // Update email sent flags on Credit Score Requests
            updateEmailSentFlags();
            
        } catch (Exception e) {
            System.debug('Error in CreditScoreEmailNotificationQueueable: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Log error for monitoring
            logError(e);
        }
    }
    
    /**
     * Send credit score notification emails to customers
     */
    private void sendCreditScoreNotifications() {
        try {
            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
            
            for (Account account : accounts) {
                if (String.isNotBlank(account.Email__c) && creditScores.containsKey(account.Id)) {
                    Credit_Score__c creditScore = creditScores.get(account.Id);
                    
                    Messaging.SingleEmailMessage email = createCreditScoreEmail(account, creditScore);
                    if (email != null) {
                        emailsToSend.add(email);
                    }
                }
            }
            
            if (!emailsToSend.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend);
                
                // Log email results
                for (Integer i = 0; i < results.size(); i++) {
                    Messaging.SendEmailResult result = results[i];
                    if (result.isSuccess()) {
                        System.debug('Email sent successfully to: ' + emailsToSend[i].getToAddresses()[0]);
                    } else {
                        System.debug('Email failed to: ' + emailsToSend[i].getToAddresses()[0] + 
                                   ' - Errors: ' + result.getErrors());
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Error sending credit score notifications: ' + e.getMessage());
            // Don't fail the main process for email errors
        }
    }
    
    /**
     * Create credit score notification email
     * @param account Customer account
     * @param creditScore Credit score record
     * @return Configured email message
     */
    private Messaging.SingleEmailMessage createCreditScoreEmail(Account account, Credit_Score__c creditScore) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set recipient
            email.setToAddresses(new String[] { account.Email__c });
            
            // Set sender (use organization-wide email address if available)
            email.setSenderDisplayName('Digi-Credit Team');
            
            // Set subject
            String subject = 'Your Credit Score is Ready - ' + 
                           CreditScoreUtils.formatScore(creditScore.Total_Score__c) + 
                           ' (' + creditScore.Score_Status__c + ')';
            email.setSubject(subject);
            
            // Set HTML body
            String htmlBody = buildEmailHtmlBody(account, creditScore);
            email.setHtmlBody(htmlBody);
            
            // Set plain text body
            String plainTextBody = buildEmailPlainTextBody(account, creditScore);
            email.setPlainTextBody(plainTextBody);
            
            // Set email options
            email.setSaveAsActivity(false); // Don't create activity records
            email.setUseSignature(false);
            
            return email;
            
        } catch (Exception e) {
            System.debug('Error creating email for account ' + account.Id + ': ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Build HTML email body
     * @param account Customer account
     * @param creditScore Credit score record
     * @return HTML email content
     */
    private String buildEmailHtmlBody(Account account, Credit_Score__c creditScore) {
        String colorCode = getColorCode(creditScore.Score_Color__c);
        String scoreFormatted = CreditScoreUtils.formatScore(creditScore.Total_Score__c);
        
        String htmlBody = '<html><body style="font-family: Arial, sans-serif;">';
        htmlBody += '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">';
        
        // Header
        htmlBody += '<h1 style="color: #333; text-align: center;">Your Credit Score is Ready!</h1>';
        
        // Greeting
        htmlBody += '<p>Dear ' + account.Name + ',</p>';
        
        // Score display
        htmlBody += '<div style="text-align: center; margin: 30px 0;">';
        htmlBody += '<div style="background-color: ' + colorCode + '; color: white; padding: 20px; border-radius: 10px; display: inline-block;">';
        htmlBody += '<h2 style="margin: 0; font-size: 36px;">' + scoreFormatted + '</h2>';
        htmlBody += '<p style="margin: 5px 0 0 0; font-size: 18px;">' + creditScore.Score_Status__c + '</p>';
        htmlBody += '</div></div>';
        
        // Score breakdown
        htmlBody += '<h3>Score Breakdown:</h3>';
        htmlBody += '<ul>';
        htmlBody += '<li>Base Score: ' + CreditScoreUtils.formatScore(creditScore.Base_Score__c) + '</li>';
        htmlBody += '<li>Profile Completion: ' + CreditScoreUtils.formatScore(creditScore.Internal_Fields_Score__c) + '</li>';
        htmlBody += '<li>Payment History: ' + CreditScoreUtils.formatScore(creditScore.External_Billing_Score__c) + '</li>';
        htmlBody += '<li>Credit Bureau Data: ' + CreditScoreUtils.formatScore(creditScore.API_Score__c) + '</li>';
        htmlBody += '</ul>';
        
        // Improvement suggestions
        if (String.isNotBlank(creditScore.Missing_Fields__c)) {
            htmlBody += '<h3>Improve Your Score:</h3>';
            htmlBody += '<p>Complete these profile fields to potentially improve your score:</p>';
            htmlBody += '<ul>';
            List<String> missingFields = creditScore.Missing_Fields__c.split(', ');
            for (String field : missingFields) {
                htmlBody += '<li>' + field + '</li>';
            }
            htmlBody += '</ul>';
        }
        
        // Footer
        htmlBody += '<hr style="margin: 30px 0;">';
        htmlBody += '<p style="font-size: 12px; color: #666;">This credit score was calculated on ' + 
                   creditScore.Calculation_Date__c.format('MMMM d, yyyy') + '.</p>';
        htmlBody += '<p style="font-size: 12px; color: #666;">Universal Containers Credit Services</p>';
        
        htmlBody += '</div></body></html>';
        
        return htmlBody;
    }
    
    /**
     * Build plain text email body
     * @param account Customer account
     * @param creditScore Credit score record
     * @return Plain text email content
     */
    private String buildEmailPlainTextBody(Account account, Credit_Score__c creditScore) {
        String scoreFormatted = CreditScoreUtils.formatScore(creditScore.Total_Score__c);
        
        String plainText = 'Dear ' + account.Name + ',\n\n';
        plainText += 'Your credit score is ready!\n\n';
        plainText += 'Credit Score: ' + scoreFormatted + ' (' + creditScore.Score_Status__c + ')\n\n';
        
        plainText += 'Score Breakdown:\n';
        plainText += '- Base Score: ' + CreditScoreUtils.formatScore(creditScore.Base_Score__c) + '\n';
        plainText += '- Profile Completion: ' + CreditScoreUtils.formatScore(creditScore.Internal_Fields_Score__c) + '\n';
        plainText += '- Payment History: ' + CreditScoreUtils.formatScore(creditScore.External_Billing_Score__c) + '\n';
        plainText += '- Credit Bureau Data: ' + CreditScoreUtils.formatScore(creditScore.API_Score__c) + '\n\n';
        
        if (String.isNotBlank(creditScore.Missing_Fields__c)) {
            plainText += 'Improve Your Score:\n';
            plainText += 'Complete these profile fields to potentially improve your score:\n';
            List<String> missingFields = creditScore.Missing_Fields__c.split(', ');
            for (String field : missingFields) {
                plainText += '- ' + field + '\n';
            }
            plainText += '\n';
        }
        
        plainText += 'This credit score was calculated on ' + 
                    creditScore.Calculation_Date__c.format('MMMM d, yyyy') + '.\n\n';
        plainText += 'Universal Containers Credit Services';
        
        return plainText;
    }
    
    /**
     * Get color code for email styling
     * @param scoreColor Score color (Red, Yellow, Green)
     * @return Hex color code
     */
    private String getColorCode(String scoreColor) {
        if (scoreColor == 'Green') {
            return '#28a745'; // Success green
        } else if (scoreColor == 'Yellow') {
            return '#ffc107'; // Warning yellow
        } else {
            return '#dc3545'; // Danger red
        }
    }
    
    /**
     * Update email sent flags on Credit Score Requests
     */
    private void updateEmailSentFlags() {
        try {
            Set<Id> accountIds = new Set<Id>();
            for (Account acc : accounts) {
                accountIds.add(acc.Id);
            }
            
            List<Credit_Score_Request__c> requestsToUpdate = [
                SELECT Id, Email_Sent__c, Email_Sent_Date__c
                FROM Credit_Score_Request__c
                WHERE Customer__c IN :accountIds
                AND Request_Status__c = 'Completed'
                AND Email_Sent__c = false
                WITH SECURITY_ENFORCED
            ];
            
            for (Credit_Score_Request__c request : requestsToUpdate) {
                request.Email_Sent__c = true;
                request.Email_Sent_Date__c = System.now();
            }
            
            if (!requestsToUpdate.isEmpty()) {
                update requestsToUpdate;
                System.debug('Updated email sent flags for ' + requestsToUpdate.size() + ' requests');
            }
            
        } catch (Exception e) {
            System.debug('Error updating email sent flags: ' + e.getMessage());
            // Don't fail the main process for flag update errors
        }
    }
    
    /**
     * Log error for monitoring and debugging
     * @param e Exception that occurred
     */
    private void logError(Exception e) {
        try {
            System.debug('=== CREDIT SCORE EMAIL NOTIFICATION ERROR ===');
            System.debug('Account Count: ' + (accounts != null ? accounts.size() : 0));
            System.debug('Credit Score Count: ' + (creditScores != null ? creditScores.size() : 0));
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('=============================================');
            
        } catch (Exception logException) {
            System.debug('Error logging failed: ' + logException.getMessage());
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________
