/**
 * Handler class for processing credit score requests received via email
 * Processes inbound emails, validates customer information, calculates credit scores,
 * and sends formatted credit score reports back to customers
 */
public without sharing class CreditScoreEmailRequestHandler implements Messaging.InboundEmailHandler {
    
    // Constants for email processing
    private static final String CREDIT_SCORE_EMAIL_TEMPLATE = 'Credit_Score_Report_Template';
    private static final String FROM_EMAIL_ADDRESS = 'creditscore@digicredit.com';
    private static final String SUBJECT_PREFIX = 'Your Credit Score Report - ';
    
    /**
     * Main method to handle inbound emails for credit score requests
     * @param email Inbound email message
     * @param envelope Email envelope information
     * @return Messaging.InboundEmailResult
     */
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, 
                                                          Messaging.InboundEnvelope envelope) {
        
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            System.debug('Processing credit score email request from: ' + envelope.fromAddress);
            
            // Extract customer information from email
            CustomerEmailInfo customerInfo = extractCustomerInfo(email, envelope);
            
            // Find or create customer account
            Account customerAccount = findOrCreateCustomer(customerInfo);
            
            if (customerAccount == null) {
                sendErrorEmail(envelope.fromAddress, 'Unable to process your request. Please contact support.');
                result.success = true;
                return result;
            }
            
            // Create credit score request record
            Credit_Score_Request__c request = createEmailCreditScoreRequest(customerAccount.Id, customerInfo);
            
            // Calculate credit score
            Credit_Score__c creditScore = CreditScoreCalculationService.calculateCreditScore(customerAccount.Id);
            
            // Update request with results
            updateRequestWithResults(request.Id, creditScore);
            
            // Send formatted credit score email
            sendCreditScoreEmail(customerAccount, creditScore, envelope.fromAddress);
            
            result.success = true;
            System.debug('Successfully processed credit score request for: ' + customerAccount.Name);
            
        } catch (Exception e) {
            System.debug('Error processing credit score email: ' + e.getMessage());
            sendErrorEmail(envelope.fromAddress, 'An error occurred processing your request. Please try again later.');
            result.success = true; // Still return success to prevent email bounce
        }
        
        return result;
    }
    
    /**
     * Extract customer information from email content and headers
     * @param email Inbound email message
     * @param envelope Email envelope
     * @return CustomerEmailInfo wrapper with extracted data
     */
    private CustomerEmailInfo extractCustomerInfo(Messaging.InboundEmail email, 
                                                 Messaging.InboundEnvelope envelope) {
        
        CustomerEmailInfo info = new CustomerEmailInfo();
        info.emailAddress = envelope.fromAddress;
        info.requestChannel = 'Email';
        info.requestDate = System.now();
        
        // Extract information from email body
        String emailBody = '';
        if (email.plainTextBody != null) {
            emailBody = email.plainTextBody.toLowerCase();
        } else if (email.htmlBody != null) {
            emailBody = email.htmlBody.toLowerCase();
        }
        
        // Parse customer details from email content
        List<String> firstNameKeywords = new List<String>{'first name', 'firstname'};
        List<String> lastNameKeywords = new List<String>{'last name', 'lastname', 'surname'};
        List<String> phoneKeywords = new List<String>{'phone', 'mobile', 'contact'};
        List<String> idKeywords = new List<String>{'customer id', 'id', 'reference'};
        
        info.firstName = extractFieldFromEmail(emailBody, firstNameKeywords);
        info.lastName = extractFieldFromEmail(emailBody, lastNameKeywords);
        info.phone = extractFieldFromEmail(emailBody, phoneKeywords);
        info.externalId = extractFieldFromEmail(emailBody, idKeywords);
        
        // Extract from subject line if available
        if (String.isNotBlank(email.subject)) {
            String subject = email.subject.toLowerCase();
            if (info.externalId == null) {
                List<String> subjectIdKeywords = new List<String>{'id', 'ref', 'customer'};
                info.externalId = extractFieldFromEmail(subject, subjectIdKeywords);
            }
        }
        
        return info;
    }
    
    /**
     * Extract specific field value from email text using multiple possible keywords
     * @param emailText Email content to search
     * @param keywords List of possible field identifiers
     * @return Extracted field value or null
     */
    private String extractFieldFromEmail(String emailText, List<String> keywords) {
        if (String.isBlank(emailText) || keywords == null) return null;
        
        for (String keyword : keywords) {
            // Look for patterns like "First Name: John" or "firstname=john"
            String regexPattern = keyword + '\\s*[:=]\\s*([^\\n\\r,;]+)';
            Pattern pattern = Pattern.compile(regexPattern);
            Matcher matcher = pattern.matcher(emailText);
            
            if (matcher.find()) {
                String value = matcher.group(1).trim();
                if (String.isNotBlank(value)) {
                    return value;
                }
            }
        }
        
        return null;
    }
    
    /**
     * Find existing customer or create new one based on email information
     * @param customerInfo Extracted customer information
     * @return Account record for the customer
     */
    private Account findOrCreateCustomer(CustomerEmailInfo customerInfo) {
        
        // First try to find by email
        List<Account> existingAccounts = [
            SELECT Id, Name, PersonEmail, Phone, External_Customer_ID__c, 
                   Current_Credit_Score__c, Last_Score_Calculation__c
            FROM Account 
            WHERE PersonEmail = :customerInfo.emailAddress 
            AND IsPersonAccount = true
            LIMIT 1
        ];
        
        if (!existingAccounts.isEmpty()) {
            return existingAccounts[0];
        }
        
        // Try to find by external ID if provided
        if (String.isNotBlank(customerInfo.externalId)) {
            existingAccounts = [
                SELECT Id, Name, PersonEmail, Phone, External_Customer_ID__c,
                       Current_Credit_Score__c, Last_Score_Calculation__c
                FROM Account 
                WHERE External_Customer_ID__c = :customerInfo.externalId
                AND IsPersonAccount = true
                LIMIT 1
            ];
            
            if (!existingAccounts.isEmpty()) {
                // Update email if different
                Account existing = existingAccounts[0];
                if (existing.PersonEmail != customerInfo.emailAddress) {
                    existing.PersonEmail = customerInfo.emailAddress;
                    update existing;
                }
                return existing;
            }
        }
        
        // Create new customer if sufficient information provided
        if (String.isNotBlank(customerInfo.firstName) && String.isNotBlank(customerInfo.lastName)) {
            return createNewCustomerAccount(customerInfo);
        }
        
        return null; // Insufficient information to create customer
    }
    
    /**
     * Create new customer account from email information
     * @param customerInfo Customer information from email
     * @return New Account record
     */
    private Account createNewCustomerAccount(CustomerEmailInfo customerInfo) {
        
        // Get Person Account Record Type
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                                      .get('PersonAccount').getRecordTypeId();
        
        Account newAccount = new Account(
            FirstName = customerInfo.firstName,
            LastName = customerInfo.lastName,
            PersonEmail = customerInfo.emailAddress,
            Phone = customerInfo.phone,
            External_Customer_ID__c = customerInfo.externalId,
            RecordTypeId = personAccountRecordTypeId
        );
        
        insert newAccount;
        
        // Refresh to get Person Account fields
        return [SELECT Id, Name, PersonEmail, Phone, External_Customer_ID__c,
                       Current_Credit_Score__c, Last_Score_Calculation__c
                FROM Account WHERE Id = :newAccount.Id LIMIT 1];
    }
    
    /**
     * Create credit score request record for email channel
     * @param accountId Customer account ID
     * @param customerInfo Customer information from email
     * @return Credit_Score_Request__c record
     */
    private Credit_Score_Request__c createEmailCreditScoreRequest(Id accountId, CustomerEmailInfo customerInfo) {
        
        Credit_Score_Request__c request = new Credit_Score_Request__c(
            Customer__c = accountId,
            Request_Channel__c = 'Email',
            Request_Status__c = 'Processing',
            Requested_Date__c = customerInfo.requestDate,
            Processing_Notes__c = 'Email request from: ' + customerInfo.emailAddress
        );
        
        insert request;
        return request;
    }
    
    /**
     * Update credit score request with calculation results
     * @param requestId Request record ID
     * @param creditScore Calculated credit score
     */
    private void updateRequestWithResults(Id requestId, Credit_Score__c creditScore) {
        
        Credit_Score_Request__c request = new Credit_Score_Request__c(
            Id = requestId,
            Request_Status__c = 'Completed',
            Completed_Date__c = System.now(),
            Credit_Score_Result__c = creditScore.Id
        );
        
        update request;
    }
    
    /**
     * Send formatted credit score report email to customer
     * @param customerAccount Customer account record
     * @param creditScore Calculated credit score record
     * @param toEmailAddress Customer email address
     */
    private void sendCreditScoreEmail(Account customerAccount, Credit_Score__c creditScore, String toEmailAddress) {
        
        // Generate HTML email content with gauge visualization
        String emailHtml = generateCreditScoreEmailHtml(customerAccount, creditScore);
        
        // Create and send email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { toEmailAddress });
        email.setSubject(SUBJECT_PREFIX + customerAccount.Name);
        email.setHtmlBody(emailHtml);
        email.setSenderDisplayName('DigiCredit Score Team');
        
        // Set reply-to address
        email.setReplyTo(FROM_EMAIL_ADDRESS);
        
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            System.debug('Credit score email sent successfully to: ' + toEmailAddress);
        } catch (Exception e) {
            System.debug('Error sending credit score email: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Generate HTML email content with credit score visualization
     * @param customerAccount Customer account
     * @param creditScore Credit score record
     * @return HTML email content
     */
    private String generateCreditScoreEmailHtml(Account customerAccount, Credit_Score__c creditScore) {
        
        // Calculate display values
        Decimal totalScore = creditScore.Total_Score__c != null ? creditScore.Total_Score__c : 0;
        String scoreStatus = CreditScoreUtils.determineScoreStatus(totalScore);
        String scoreColor = CreditScoreUtils.getScoreColor(totalScore);
        String scoreRange = getScoreRangeText(totalScore);
        
        // Calculate percentage for gauge (0-750 range)
        Decimal percentage = ((totalScore - 0) / (750 - 0)) * 100;
        percentage = Math.max(0, Math.min(100, percentage));
        
        // Get color values
        String gaugeColor = getGaugeColorHex(scoreColor);
        String statusBgColor = getStatusBackgroundColor(scoreColor);
        
        // Build HTML email
        String html = '<!DOCTYPE html>' +
            '<html><head><meta charset="UTF-8">' +
            '<title>Your Credit Score Report</title>' +
            '<style>' +
            'body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f4f6f9; }' +
            '.container { max-width: 600px; margin: 0 auto; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }' +
            '.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }' +
            '.content { padding: 30px; }' +
            '.score-section { text-align: center; margin: 30px 0; }' +
            '.gauge-container { position: relative; display: inline-block; margin: 20px 0; }' +
            '.gauge-score { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); font-size: 24px; font-weight: bold; color: #333; }' +
            '.gauge-range { display: flex; justify-content: space-between; width: 160px; margin: 10px auto 0; font-size: 12px; color: #666; }' +
            '.score-status { display: inline-block; padding: 8px 16px; border-radius: 20px; font-weight: bold; margin: 15px 0; color: white; background-color: ' + statusBgColor + '; }' +
            '.breakdown { background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }' +
            '.breakdown-item { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #e9ecef; }' +
            '.breakdown-item:last-child { border-bottom: none; }' +
            '.footer { background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #666; }' +
            '</style></head><body>' +
            
            '<div class="container">' +
            '<div class="header">' +
            '<h1>Your Credit Score Report</h1>' +
            '<p>Hello ' + customerAccount.Name + ',</p>' +
            '<p>Your credit score has been calculated and is ready for review.</p>' +
            '</div>' +
            
            '<div class="content">' +
            '<div class="score-section">' +
            '<div class="gauge-container">' +
            generateSVGGauge(percentage, gaugeColor) +
            '<div class="gauge-score">' + percentage.intValue() + '%</div>' +
            '</div>' +
            '<div class="gauge-range"><span>0</span><span>750</span></div>' +
            '<div class="score-status">' + scoreStatus + '</div>' +
            '<p><strong>Score: ' + totalScore.intValue() + ' | Range: ' + scoreRange + '</strong></p>' +
            '<p style="color: #666; font-size: 14px;">Calculated on: ' + 
            System.now().format('MMMM dd, yyyy') + '</p>' +
            '</div>' +
            
            '<div class="breakdown">' +
            '<h3>Score Breakdown</h3>' +
            '<div class="breakdown-item"><span>Base Score:</span><span>' + 
            (creditScore.Base_Score__c != null ? creditScore.Base_Score__c.intValue() : 0) + '</span></div>' +
            '<div class="breakdown-item"><span>Profile Completion:</span><span>' + 
            (creditScore.Internal_Fields_Score__c != null ? creditScore.Internal_Fields_Score__c.intValue() : 0) + '</span></div>' +
            '<div class="breakdown-item"><span>Payment History:</span><span>' + 
            (creditScore.External_Billing_Score__c != null ? creditScore.External_Billing_Score__c.intValue() : 0) + '</span></div>' +
            '<div class="breakdown-item"><span>Credit Bureau:</span><span>' + 
            (creditScore.API_Score__c != null ? creditScore.API_Score__c.intValue() : 0) + '</span></div>' +
            '</div>' +
            
            '<div style="background-color: #e3f2fd; padding: 15px; border-radius: 8px; margin: 20px 0;">' +
            '<h4 style="margin-top: 0; color: #1976d2;">What This Means</h4>' +
            '<p style="margin-bottom: 0; font-size: 14px;">Your credit score of <strong>' + totalScore.intValue() + 
            '</strong> falls in the <strong>' + scoreStatus + '</strong> category. ' +
            getScoreExplanation(scoreStatus) + '</p>' +
            '</div>' +
            
            '</div>' +
            
            '<div class="footer">' +
            '<p>This report was generated automatically by DigiCredit Score Engine.</p>' +
            '<p>For questions or support, please contact us at support@digicredit.com</p>' +
            '<p style="margin-top: 15px; font-size: 10px;">© 2024 DigiCredit. All rights reserved.</p>' +
            '</div>' +
            '</div>' +
            
            '</body></html>';
        
        return html;
    }
    
    /**
     * Generate SVG gauge for email visualization
     * @param percentage Score percentage (0-100)
     * @param color Gauge color
     * @return SVG markup string
     */
    private String generateSVGGauge(Decimal percentage, String color) {
        
        // Calculate stroke-dashoffset for the progress arc
        Decimal radius = 80;
        Decimal circumference = Math.PI * radius; // Half circle
        Decimal offset = circumference - (percentage / 100) * circumference;
        
        return '<svg width="200" height="120" viewBox="0 0 200 120">' +
               '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" stroke="#e5e5e5" stroke-width="12" stroke-linecap="round"></path>' +
               '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" stroke="' + color + '" stroke-width="12" stroke-linecap="round" ' +
               'stroke-dasharray="' + circumference + ' ' + circumference + '" stroke-dashoffset="' + offset + '"></path>' +
               '</svg>';
    }
    
    /**
     * Get score range text based on total score
     * @param totalScore Total credit score
     * @return Score range string
     */
    private String getScoreRangeText(Decimal totalScore) {
        if (totalScore >= 600 && totalScore <= 750) {
            return '600-750';
        } else if (totalScore >= 450 && totalScore < 600) {
            return '450-600';
        } else if (totalScore >= 300 && totalScore < 450) {
            return '300-450';
        } else {
            return 'N/A';
        }
    }
    
    /**
     * Get hex color for gauge based on score color
     * @param scoreColor Score color (Red, Yellow, Green, Gray)
     * @return Hex color string
     */
    private String getGaugeColorHex(String scoreColor) {
        String colorLower = scoreColor.toLowerCase();
        if (colorLower == 'green') {
            return '#28a745';
        } else if (colorLower == 'yellow') {
            return '#ffc107';
        } else if (colorLower == 'red') {
            return '#dc3545';
        } else {
            return '#6c757d';
        }
    }
    
    /**
     * Get background color for status badge
     * @param scoreColor Score color
     * @return Background color string
     */
    private String getStatusBackgroundColor(String scoreColor) {
        String colorLower = scoreColor.toLowerCase();
        if (colorLower == 'green') {
            return '#28a745';
        } else if (colorLower == 'yellow') {
            return '#ffc107';
        } else if (colorLower == 'red') {
            return '#dc3545';
        } else {
            return '#6c757d';
        }
    }
    
    /**
     * Get explanation text for score status
     * @param scoreStatus Score status (Poor, Good, Excellent)
     * @return Explanation text
     */
    private String getScoreExplanation(String scoreStatus) {
        String statusLower = scoreStatus.toLowerCase();
        if (statusLower == 'excellent') {
            return 'This is an excellent score that demonstrates strong creditworthiness and financial responsibility.';
        } else if (statusLower == 'good') {
            return 'This is a good score that shows reliable credit management with room for improvement.';
        } else if (statusLower == 'poor') {
            return 'This score indicates areas for improvement in credit management and financial habits.';
        } else {
            return 'Please contact support for more information about your score.';
        }
    }
    
    /**
     * Send error email to customer when processing fails
     * @param toEmailAddress Customer email address
     * @param errorMessage Error message to include
     */
    private void sendErrorEmail(String toEmailAddress, String errorMessage) {
        
        String html = '<!DOCTYPE html>' +
            '<html><head><meta charset="UTF-8"></head><body style="font-family: Arial, sans-serif; padding: 20px;">' +
            '<div style="max-width: 500px; margin: 0 auto; text-align: center;">' +
            '<h2 style="color: #dc3545;">Credit Score Request Error</h2>' +
            '<p>' + errorMessage + '</p>' +
            '<p style="font-size: 14px; color: #666;">If you continue to experience issues, please contact our support team.</p>' +
            '<hr style="margin: 20px 0;">' +
            '<p style="font-size: 12px; color: #666;">DigiCredit Score Team<br>support@digicredit.com</p>' +
            '</div></body></html>';
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { toEmailAddress });
        email.setSubject('Credit Score Request - Processing Error');
        email.setHtmlBody(html);
        email.setSenderDisplayName('DigiCredit Score Team');
        email.setReplyTo(FROM_EMAIL_ADDRESS);
        
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            System.debug('Error sending error email: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper class for customer information extracted from email
     */
    public class CustomerEmailInfo {
        public String emailAddress { get; set; }
        public String firstName { get; set; }
        public String lastName { get; set; }
        public String phone { get; set; }
        public String externalId { get; set; }
        public String requestChannel { get; set; }
        public DateTime requestDate { get; set; }
    }
}