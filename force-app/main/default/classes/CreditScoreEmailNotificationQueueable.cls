/**
 * Queueable class for processing credit score email notifications asynchronously
 * Handles bulk email sending and credit score calculations triggered by various channels
 */
public class CreditScoreEmailNotificationQueueable implements Queueable {
    
    private List<EmailNotificationRequest> emailRequests;
    
    /**
     * Constructor for single email request
     * @param accountId Account ID to process
     * @param emailAddress Email address to send to
     * @param requestChannel Channel that triggered the request
     */
    public CreditScoreEmailNotificationQueueable(Id accountId, String emailAddress, String requestChannel) {
        this.emailRequests = new List<EmailNotificationRequest>();
        this.emailRequests.add(new EmailNotificationRequest(accountId, emailAddress, requestChannel));
    }
    
    /**
     * Constructor for bulk email requests
     * @param requests List of email notification requests
     */
    public CreditScoreEmailNotificationQueueable(List<EmailNotificationRequest> requests) {
        this.emailRequests = requests != null ? requests : new List<EmailNotificationRequest>();
    }
    
    /**
     * Constructor for CreditScoreCalculationQueueable integration
     * @param accounts List of Account records
     * @param creditScores Map of Account ID to Credit Score records
     */
    public CreditScoreEmailNotificationQueueable(List<Account> accounts, Map<Id, Credit_Score__c> creditScores) {
        this.emailRequests = new List<EmailNotificationRequest>();
        
        if (accounts != null && creditScores != null) {
            for (Account acc : accounts) {
                if (String.isNotBlank(acc.PersonEmail) && creditScores.containsKey(acc.Id)) {
                    this.emailRequests.add(new EmailNotificationRequest(acc.Id, acc.PersonEmail, 'System'));
                }
            }
        }
    }
    
    /**
     * Execute method for queueable interface
     * @param context Queueable context
     */
    public void execute(QueueableContext context) {
        
        if (emailRequests.isEmpty()) {
            System.debug('No email requests to process');
            return;
        }
        
        System.debug('Processing ' + emailRequests.size() + ' credit score email notifications');
        
        try {
            // Process each email request
            for (EmailNotificationRequest request : emailRequests) {
                processEmailNotification(request);
            }
            
            System.debug('Successfully processed all email notifications');
            
        } catch (Exception e) {
            System.debug('Error processing email notifications: ' + e.getMessage());
            // Log error but don't throw to prevent job failure
        }
    }
    
    /**
     * Process individual email notification request
     * @param request Email notification request to process
     */
    private void processEmailNotification(EmailNotificationRequest request) {
        
        try {
            // Get customer account
            Account customerAccount = getCustomerAccount(request.accountId);
            
            if (customerAccount == null) {
                System.debug('Customer account not found: ' + request.accountId);
                return;
            }
            
            // Calculate or get existing credit score
            Credit_Score__c creditScore = getOrCalculateCreditScore(request.accountId);
            
            if (creditScore == null) {
                System.debug('Unable to get credit score for account: ' + request.accountId);
                sendErrorNotification(request.emailAddress, 'Unable to calculate credit score');
                return;
            }
            
            // Create request record for tracking
            Credit_Score_Request__c requestRecord = createRequestRecord(request);
            
            // Generate and send email
            sendCreditScoreEmail(customerAccount, creditScore, request.emailAddress);
            
            // Update request record as completed
            updateRequestRecord(requestRecord.Id, creditScore.Id);
            
            System.debug('Successfully sent credit score email to: ' + request.emailAddress);
            
        } catch (Exception e) {
            System.debug('Error processing email for ' + request.emailAddress + ': ' + e.getMessage());
            sendErrorNotification(request.emailAddress, 'An error occurred processing your request');
        }
    }
    
    /**
     * Get customer account record
     * @param accountId Account ID
     * @return Account record or null
     */
    private Account getCustomerAccount(Id accountId) {
        
        try {
            return [SELECT Id, Name, PersonEmail, Phone, External_Customer_ID__c,
                           Current_Credit_Score__c, Last_Score_Calculation__c
                    FROM Account 
                    WHERE Id = :accountId 
                    AND IsPersonAccount = true 
                    LIMIT 1];
        } catch (Exception e) {
            System.debug('Error retrieving account: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Get existing credit score or calculate new one
     * @param accountId Account ID
     * @return Credit_Score__c record or null
     */
    private Credit_Score__c getOrCalculateCreditScore(Id accountId) {
        
        try {
            // First try to get existing current score
            List<Credit_Score__c> existingScores = [
                SELECT Id, Total_Score__c, Base_Score__c, Internal_Fields_Score__c,
                       External_Billing_Score__c, API_Score__c, Score_Status__c,
                       Calculation_Date__c, Is_Current__c, Missing_Fields__c
                FROM Credit_Score__c
                WHERE Customer__c = :accountId
                AND Is_Current__c = true
                ORDER BY Calculation_Date__c DESC
                LIMIT 1
            ];
            
            // If recent score exists (within 24 hours), use it
            if (!existingScores.isEmpty()) {
                Credit_Score__c existingScore = existingScores[0];
                DateTime calculationDate = existingScore.Calculation_Date__c;
                
                if (calculationDate != null && calculationDate > System.now().addHours(-24)) {
                    System.debug('Using existing credit score calculated at: ' + calculationDate);
                    return existingScore;
                }
            }
            
            // Calculate new credit score
            System.debug('Calculating new credit score for account: ' + accountId);
            return CreditScoreCalculationService.calculateCreditScore(accountId);
            
        } catch (Exception e) {
            System.debug('Error getting/calculating credit score: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Create credit score request record for tracking
     * @param request Email notification request
     * @return Credit_Score_Request__c record
     */
    private Credit_Score_Request__c createRequestRecord(EmailNotificationRequest request) {
        
        Credit_Score_Request__c requestRecord = new Credit_Score_Request__c(
            Customer__c = request.accountId,
            Request_Channel__c = request.requestChannel,
            Request_Status__c = 'Processing',
            Requested_Date__c = System.now(),
            Processing_Notes__c = 'Email notification to: ' + request.emailAddress
        );
        
        insert requestRecord;
        return requestRecord;
    }
    
    /**
     * Update request record with completion details
     * @param requestId Request record ID
     * @param creditScoreId Credit score record ID
     */
    private void updateRequestRecord(Id requestId, Id creditScoreId) {
        
        try {
            Credit_Score_Request__c requestUpdate = new Credit_Score_Request__c(
                Id = requestId,
                Request_Status__c = 'Completed',
                Completed_Date__c = System.now(),
                Credit_Score_Result__c = creditScoreId
            );
            
            update requestUpdate;
        } catch (Exception e) {
            System.debug('Error updating request record: ' + e.getMessage());
        }
    }
    
    /**
     * Send credit score email using the email handler
     * @param customerAccount Customer account
     * @param creditScore Credit score record
     * @param emailAddress Email address to send to
     */
    private void sendCreditScoreEmail(Account customerAccount, Credit_Score__c creditScore, String emailAddress) {
        
        // Generate HTML email content
        String emailHtml = generateCreditScoreEmailHtml(customerAccount, creditScore);
        
        // Create and send email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { emailAddress });
        email.setSubject('Your Credit Score Report - ' + customerAccount.Name);
        email.setHtmlBody(emailHtml);
        email.setSenderDisplayName('DigiCredit Score Team');
        email.setReplyTo('creditscore@digicredit.com');
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
    
    /**
     * Generate HTML email content (reused from email handler)
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
        
        // Build HTML email (same structure as email handler)
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
     * Send error notification email
     * @param emailAddress Email address to send to
     * @param errorMessage Error message
     */
    private void sendErrorNotification(String emailAddress, String errorMessage) {
        
        String html = '<!DOCTYPE html>' +
            '<html><head><meta charset="UTF-8"></head><body style="font-family: Arial, sans-serif; padding: 20px;">' +
            '<div style="max-width: 500px; margin: 0 auto; text-align: center;">' +
            '<h2 style="color: #dc3545;">Credit Score Request Error</h2>' +
            '<p>' + errorMessage + '</p>' +
            '<p style="font-size: 14px; color: #666;">If you continue to experience issues, please contact our support team.</p>' +
            '<hr style="margin: 20px 0;">' +
            '<p style="font-size: 12px; color: #666;">DigiCredit Score Team<br>support@digicredit.com</p>' +
            '</div></body></html>';
        
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { emailAddress });
            email.setSubject('Credit Score Request - Processing Error');
            email.setHtmlBody(html);
            email.setSenderDisplayName('DigiCredit Score Team');
            email.setReplyTo('creditscore@digicredit.com');
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            System.debug('Error sending error notification: ' + e.getMessage());
        }
    }
    
    // Helper methods (same as email handler)
    private String generateSVGGauge(Decimal percentage, String color) {
        Decimal radius = 80;
        Decimal circumference = Math.PI * radius;
        Decimal offset = circumference - (percentage / 100) * circumference;
        
        return '<svg width="200" height="120" viewBox="0 0 200 120">' +
               '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" stroke="#e5e5e5" stroke-width="12" stroke-linecap="round"></path>' +
               '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" stroke="' + color + '" stroke-width="12" stroke-linecap="round" ' +
               'stroke-dasharray="' + circumference + ' ' + circumference + '" stroke-dashoffset="' + offset + '"></path>' +
               '</svg>';
    }
    
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
     * Wrapper class for email notification requests
     */
    public class EmailNotificationRequest {
        public Id accountId { get; set; }
        public String emailAddress { get; set; }
        public String requestChannel { get; set; }
        
        public EmailNotificationRequest(Id accountId, String emailAddress, String requestChannel) {
            this.accountId = accountId;
            this.emailAddress = emailAddress;
            this.requestChannel = requestChannel;
        }
    }
}