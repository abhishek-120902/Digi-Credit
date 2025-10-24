public class CreditScoreEmailRequestHandler {
    
    /**
     * Process credit score requests from email
     * This method can be called from Email-to-Case or other email processing systems
     * @param emailAddress Customer email address
     * @param customerInfo Additional customer information from email
     * @return Success message or error details
     */
    @AuraEnabled
    public static String processCreditScoreEmailRequest(String emailAddress, Map<String, String> customerInfo) {
        try {
            if (String.isBlank(emailAddress)) {
                throw new CreditScoreRequestException('Email address is required');
            }
            
            // Find customer account by email
            Account customerAccount = findCustomerByEmail(emailAddress);
            
            if (customerAccount == null) {
                // Create new customer account if not found
                customerAccount = createCustomerFromEmail(emailAddress, customerInfo);
            }
            
            // Create credit score request
            Credit_Score_Request__c request = new Credit_Score_Request__c(
                Customer__c = customerAccount.Id,
                Request_Channel__c = 'Email',
                Request_Status__c = 'Submitted',
                Requested_Date__c = System.now(),
                Processing_Notes__c = 'Request received via email from: ' + emailAddress
            );
            
            insert request;
            
            // Send confirmation email
            sendConfirmationEmail(customerAccount, request);
            
            return 'Credit score request submitted successfully for ' + customerAccount.Name;
            
        } catch (Exception e) {
            System.debug('Error processing email credit score request: ' + e.getMessage());
            throw new AuraHandledException('Error processing request: ' + e.getMessage());
        }
    }
    
    /**
     * Process credit score requests from Case records (Email-to-Case)
     * @param caseId Case record ID
     * @return Success message
     */
    public static String processCreditScoreRequestFromCase(Id caseId) {
        try {
            // Get case details
            Case requestCase = [
                SELECT Id, Subject, Description, SuppliedEmail, SuppliedName, ContactId, Contact.AccountId
                FROM Case 
                WHERE Id = :caseId 
                LIMIT 1
            ];
            
            String emailAddress = requestCase.SuppliedEmail;
            String customerName = requestCase.SuppliedName;
            
            if (String.isBlank(emailAddress)) {
                throw new CreditScoreRequestException('No email address found in case');
            }
            
            Account customerAccount;
            
            // Check if case is linked to existing contact/account
            if (requestCase.ContactId != null && requestCase.Contact.AccountId != null) {
                customerAccount = [SELECT Id, Name, Email__c FROM Account WHERE Id = :requestCase.Contact.AccountId LIMIT 1];
            } else {
                // Find or create customer account
                customerAccount = findCustomerByEmail(emailAddress);
                if (customerAccount == null) {
                    Map<String, String> customerInfo = new Map<String, String>();
                    customerInfo.put('name', customerName);
                    customerAccount = createCustomerFromEmail(emailAddress, customerInfo);
                }
            }
            
            // Create credit score request
            Credit_Score_Request__c request = new Credit_Score_Request__c(
                Customer__c = customerAccount.Id,
                Request_Channel__c = 'Email',
                Request_Status__c = 'Submitted',
                Requested_Date__c = System.now(),
                Processing_Notes__c = 'Request received via Case #' + requestCase.Id + ' from: ' + emailAddress
            );
            
            insert request;
            
            // Update case with reference to credit score request
            requestCase.Status = 'In Progress';
            requestCase.Description = (requestCase.Description != null ? requestCase.Description + '\n\n' : '') + 
                                    'Credit Score Request Created: ' + request.Id;
            update requestCase;
            
            // Send confirmation email
            sendConfirmationEmail(customerAccount, request);
            
            return 'Credit score request created successfully';
            
        } catch (Exception e) {
            System.debug('Error processing case credit score request: ' + e.getMessage());
            throw new CreditScoreRequestException('Error processing case request: ' + e.getMessage());
        }
    }
    
    /**
     * Batch process multiple email requests
     * @param emailRequests List of email request data
     * @return List of processing results
     */
    public static List<String> processBatchEmailRequests(List<Map<String, String>> emailRequests) {
        List<String> results = new List<String>();
        
        for (Map<String, String> requestData : emailRequests) {
            try {
                String emailAddress = requestData.get('email');
                requestData.remove('email'); // Remove email from customer info map
                
                String result = processCreditScoreEmailRequest(emailAddress, requestData);
                results.add('SUCCESS: ' + result);
                
            } catch (Exception e) {
                results.add('ERROR: ' + e.getMessage());
            }
        }
        
        return results;
    }
    
    /**
     * Find customer account by email address
     * @param emailAddress Email to search for
     * @return Account record or null if not found
     */
    private static Account findCustomerByEmail(String emailAddress) {
        List<Account> accounts = [
            SELECT Id, Name, Email__c, Phone, Age__c, Custom_Field__c
            FROM Account 
            WHERE Email__c = :emailAddress 
            AND IsPersonAccount = true
            LIMIT 1
        ];
        
        return accounts.isEmpty() ? null : accounts[0];
    }
    
    /**
     * Create new customer account from email request
     * @param emailAddress Customer email
     * @param customerInfo Additional customer information
     * @return Created Account record
     */
    private static Account createCustomerFromEmail(String emailAddress, Map<String, String> customerInfo) {
        // Parse name from customer info or email
        String fullName = customerInfo.get('name');
        if (String.isBlank(fullName)) {
            fullName = emailAddress.split('@')[0].replace('.', ' ').replace('_', ' ');
            fullName = capitalizeWords(fullName);
        }
        
        // Split name into first and last
        List<String> nameParts = fullName.split(' ');
        String firstName = nameParts[0];
        String lastName = 'Customer';
        
        if (nameParts.size() > 1) {
            List<String> lastNameParts = new List<String>();
            for (Integer i = 1; i < nameParts.size(); i++) {
                lastNameParts.add(nameParts[i]);
            }
            lastName = String.join(lastNameParts, ' ');
        }
        
        Account newAccount = new Account(
            FirstName = firstName,
            LastName = lastName,
            Email__c = emailAddress,
            RecordTypeId = getPersonAccountRecordTypeId()
        );
        
        // Add additional information if provided
        if (customerInfo.containsKey('phone')) {
            newAccount.Phone = customerInfo.get('phone');
        }
        
        if (customerInfo.containsKey('age')) {
            try {
                newAccount.Age__c = Integer.valueOf(customerInfo.get('age'));
            } catch (Exception e) {
                System.debug('Invalid age value: ' + customerInfo.get('age'));
            }
        }
        
        if (customerInfo.containsKey('customField')) {
            newAccount.Custom_Field__c = customerInfo.get('customField');
        }
        
        // Generate external customer ID
        newAccount.External_Customer_ID__c = 'EMAIL_' + System.now().getTime() + '_' + Math.round(Math.random() * 1000);
        
        insert newAccount;
        
        System.debug('Created new customer account: ' + newAccount.Id + ' for email: ' + emailAddress);
        
        return newAccount;
    }
    
    /**
     * Get Person Account Record Type ID
     * @return Record Type ID for Person Accounts
     */
    private static Id getPersonAccountRecordTypeId() {
        try {
            RecordType personAccountRT = [
                SELECT Id 
                FROM RecordType 
                WHERE SObjectType = 'Account' 
                AND DeveloperName = 'PersonAccount' 
                LIMIT 1
            ];
            return personAccountRT.Id;
        } catch (Exception e) {
            System.debug('Person Account Record Type not found, using default');
            return null;
        }
    }
    
    /**
     * Send confirmation email to customer
     * @param account Customer account
     * @param request Credit score request
     */
    private static void sendConfirmationEmail(Account account, Credit_Score_Request__c request) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            email.setToAddresses(new String[] { account.Email__c });
            email.setSenderDisplayName('Digi-Credit Team');
            email.setSubject('Credit Score Request Confirmation - Request #' + request.Id);
            
            String htmlBody = buildConfirmationEmailBody(account, request);
            email.setHtmlBody(htmlBody);
            
            String plainTextBody = buildConfirmationPlainTextBody(account, request);
            email.setPlainTextBody(plainTextBody);
            
            email.setSaveAsActivity(false);
            email.setUseSignature(false);
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            
            System.debug('Confirmation email sent to: ' + account.Email__c);
            
        } catch (Exception e) {
            System.debug('Error sending confirmation email: ' + e.getMessage());
            // Don't fail the main process if email fails
        }
    }
    
    /**
     * Build confirmation email HTML body
     * @param account Customer account
     * @param request Credit score request
     * @return HTML email content
     */
    private static String buildConfirmationEmailBody(Account account, Credit_Score_Request__c request) {
        String htmlBody = '<html><body style="font-family: Arial, sans-serif;">';
        htmlBody += '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">';
        
        // Header
        htmlBody += '<h1 style="color: #333; text-align: center;">✅ Credit Score Request Received</h1>';
        
        // Greeting
        htmlBody += '<p>Dear ' + account.Name + ',</p>';
        
        // Confirmation message
        htmlBody += '<div style="background-color: #d4edda; border: 1px solid #c3e6cb; padding: 15px; border-radius: 5px; margin: 20px 0;">';
        htmlBody += '<p style="margin: 0; color: #155724;"><strong>Your credit score request has been successfully received and is being processed.</strong></p>';
        htmlBody += '</div>';
        
        // Request details
        htmlBody += '<h3>Request Details:</h3>';
        htmlBody += '<ul>';
        htmlBody += '<li><strong>Request ID:</strong> ' + request.Id + '</li>';
        htmlBody += '<li><strong>Request Date:</strong> ' + request.Requested_Date__c.format('MMMM d, yyyy \'at\' h:mm a') + '</li>';
        htmlBody += '<li><strong>Channel:</strong> ' + request.Request_Channel__c + '</li>';
        htmlBody += '<li><strong>Status:</strong> ' + request.Request_Status__c + '</li>';
        htmlBody += '</ul>';
        
        // What happens next
        htmlBody += '<h3>What Happens Next:</h3>';
        htmlBody += '<ol>';
        htmlBody += '<li>Our system will calculate your credit score based on available information</li>';
        htmlBody += '<li>You will receive an email with your credit score results within 24 hours</li>';
        htmlBody += '<li>The email will include a detailed breakdown and improvement suggestions</li>';
        htmlBody += '</ol>';
        
        // Contact information
        htmlBody += '<div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">';
        htmlBody += '<h4 style="margin-top: 0;">Need Help?</h4>';
        htmlBody += '<p style="margin-bottom: 0;">If you have any questions about your request, please contact our customer service team.</p>';
        htmlBody += '</div>';
        
        // Footer
        htmlBody += '<hr style="margin: 30px 0;">';
        htmlBody += '<p style="font-size: 12px; color: #666;">Universal Containers Credit Services</p>';
        htmlBody += '<p style="font-size: 12px; color: #666;">This is an automated confirmation email.</p>';
        
        htmlBody += '</div></body></html>';
        
        return htmlBody;
    }
    
    /**
     * Build confirmation email plain text body
     * @param account Customer account
     * @param request Credit score request
     * @return Plain text email content
     */
    private static String buildConfirmationPlainTextBody(Account account, Credit_Score_Request__c request) {
        String plainText = 'Dear ' + account.Name + ',\n\n';
        plainText += 'Your credit score request has been successfully received and is being processed.\n\n';
        
        plainText += 'Request Details:\n';
        plainText += '- Request ID: ' + request.Id + '\n';
        plainText += '- Request Date: ' + request.Requested_Date__c.format('MMMM d, yyyy \'at\' h:mm a') + '\n';
        plainText += '- Channel: ' + request.Request_Channel__c + '\n';
        plainText += '- Status: ' + request.Request_Status__c + '\n\n';
        
        plainText += 'What Happens Next:\n';
        plainText += '1. Our system will calculate your credit score based on available information\n';
        plainText += '2. You will receive an email with your credit score results within 24 hours\n';
        plainText += '3. The email will include a detailed breakdown and improvement suggestions\n\n';
        
        plainText += 'If you have any questions about your request, please contact our customer service team.\n\n';
        plainText += 'Universal Containers Credit Services\n';
        plainText += 'This is an automated confirmation email.';
        
        return plainText;
    }
    
    /**
     * Capitalize words in a string
     * @param input Input string
     * @return Capitalized string
     */
    private static String capitalizeWords(String input) {
        if (String.isBlank(input)) return input;
        
        List<String> words = input.split(' ');
        List<String> capitalizedWords = new List<String>();
        
        for (String word : words) {
            if (String.isNotBlank(word)) {
                capitalizedWords.add(word.substring(0, 1).toUpperCase() + 
                                   (word.length() > 1 ? word.substring(1).toLowerCase() : ''));
            }
        }
        
        return String.join(capitalizedWords, ' ');
    }
    
    /**
     * Custom exception for credit score request errors
     */
    public class CreditScoreRequestException extends Exception {
        // Custom exception class
    }
}
