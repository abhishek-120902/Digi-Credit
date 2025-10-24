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
            
            // Set HTML body with embedded gauge visualization
            String htmlBody = buildEmailHtmlBodyWithGauge(account, creditScore);
            email.setHtmlBody(htmlBody);
            
            // Set plain text body
            String plainTextBody = buildEmailPlainTextBody(account, creditScore);
            email.setPlainTextBody(plainTextBody);
            
            // Create and attach credit score visualization
            List<Messaging.EmailFileAttachment> attachments = createCreditScoreAttachments(account, creditScore);
            if (!attachments.isEmpty()) {
                email.setFileAttachments(attachments);
            }
            
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
     * Build HTML email body with embedded SVG gauge
     * @param account Customer account
     * @param creditScore Credit score record
     * @return HTML email content with gauge visualization
     */
    private String buildEmailHtmlBodyWithGauge(Account account, Credit_Score__c creditScore) {
        String colorCode = getColorCode(creditScore.Score_Color__c);
        String scoreFormatted = CreditScoreUtils.formatScore(creditScore.Total_Score__c);
        
        // Calculate gauge properties
        Decimal scorePercentage = calculateScorePercentage(creditScore.Total_Score__c);
        String gaugeSvg = generateGaugeSvg(scorePercentage, colorCode);
        
        String htmlBody = '<html><head><style>';
        htmlBody += 'body { font-family: Arial, sans-serif; margin: 0; padding: 0; }';
        htmlBody += '.email-container { max-width: 600px; margin: 0 auto; padding: 20px; }';
        htmlBody += '.header { text-align: center; color: #333; margin-bottom: 30px; }';
        htmlBody += '.gauge-section { text-align: center; margin: 40px 0; }';
        htmlBody += '.score-details { background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }';
        htmlBody += '.breakdown-list { list-style-type: none; padding: 0; }';
        htmlBody += '.breakdown-item { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #e9ecef; }';
        htmlBody += '.footer { border-top: 1px solid #e9ecef; padding-top: 20px; margin-top: 30px; font-size: 12px; color: #666; }';
        htmlBody += '</style></head><body>';
        
        htmlBody += '<div class="email-container">';
        
        // Header
        htmlBody += '<div class="header">';
        htmlBody += '<h1>🎉 Your Credit Score is Ready!</h1>';
        htmlBody += '<p>Dear ' + account.Name + ',</p>';
        htmlBody += '<p>We\'ve calculated your credit score and it\'s ready for review.</p>';
        htmlBody += '</div>';
        
        // Gauge visualization
        htmlBody += '<div class="gauge-section">';
        htmlBody += gaugeSvg;
        htmlBody += '<h2 style="margin: 20px 0 10px 0; color: ' + colorCode + ';">' + scoreFormatted + '</h2>';
        htmlBody += '<p style="font-size: 18px; color: ' + colorCode + '; font-weight: bold;">' + creditScore.Score_Status__c + '</p>';
        htmlBody += '</div>';
        
        // Score breakdown
        htmlBody += '<div class="score-details">';
        htmlBody += '<h3 style="margin-top: 0;">📊 Score Breakdown</h3>';
        htmlBody += '<ul class="breakdown-list">';
        htmlBody += '<li class="breakdown-item"><span>Base Score:</span><span><strong>' + CreditScoreUtils.formatScore(creditScore.Base_Score__c) + '</strong></span></li>';
        htmlBody += '<li class="breakdown-item"><span>Profile Completion:</span><span><strong>' + CreditScoreUtils.formatScore(creditScore.Internal_Fields_Score__c) + '</strong></span></li>';
        htmlBody += '<li class="breakdown-item"><span>Payment History:</span><span><strong>' + CreditScoreUtils.formatScore(creditScore.External_Billing_Score__c) + '</strong></span></li>';
        htmlBody += '<li class="breakdown-item"><span>Credit Bureau Data:</span><span><strong>' + CreditScoreUtils.formatScore(creditScore.API_Score__c) + '</strong></span></li>';
        htmlBody += '</ul>';
        htmlBody += '</div>';
        
        // Improvement suggestions
        if (String.isNotBlank(creditScore.Missing_Fields__c)) {
            htmlBody += '<div class="score-details">';
            htmlBody += '<h3 style="margin-top: 0;">💡 Improve Your Score</h3>';
            htmlBody += '<p>Complete these profile fields to potentially improve your score:</p>';
            htmlBody += '<ul>';
            List<String> missingFields = creditScore.Missing_Fields__c.split(', ');
            for (String field : missingFields) {
                htmlBody += '<li>' + field + '</li>';
            }
            htmlBody += '</ul>';
            htmlBody += '</div>';
        }
        
        // Call to action
        htmlBody += '<div style="text-align: center; margin: 30px 0;">';
        htmlBody += '<p>📱 <strong>Access your full credit report and manage your profile in our customer portal.</strong></p>';
        htmlBody += '</div>';
        
        // Footer
        htmlBody += '<div class="footer">';
        htmlBody += '<p>This credit score was calculated on ' + creditScore.Calculation_Date__c.format('MMMM d, yyyy') + '.</p>';
        htmlBody += '<p><strong>Universal Containers Credit Services</strong><br/>Your trusted partner in financial health.</p>';
        htmlBody += '</div>';
        
        htmlBody += '</div></body></html>';
        
        return htmlBody;
    }
    
    /**
     * Generate SVG gauge for email
     * @param percentage Score percentage (0-100)
     * @param color Gauge color
     * @return SVG markup as string
     */
    private String generateGaugeSvg(Decimal percentage, String color) {
        // Calculate dash offset for the progress arc
        Decimal radius = 80;
        Decimal circumference = Math.PI * radius;
        Decimal offset = circumference - (percentage / 100) * circumference;
        
        String svg = '<svg width="200" height="120" viewBox="0 0 200 120" style="display: block; margin: 0 auto;">';
        
        // Background arc
        svg += '<path d="M 20 100 A 80 80 0 0 1 180 100" ';
        svg += 'fill="none" stroke="#e5e5e5" stroke-width="12" stroke-linecap="round"></path>';
        
        // Progress arc
        svg += '<path d="M 20 100 A 80 80 0 0 1 180 100" ';
        svg += 'fill="none" stroke="' + color + '" stroke-width="12" stroke-linecap="round" ';
        svg += 'stroke-dasharray="' + circumference + ' ' + circumference + '" ';
        svg += 'stroke-dashoffset="' + offset + '"></path>';
        
        // Percentage text
        svg += '<text x="100" y="85" text-anchor="middle" font-family="Arial, sans-serif" ';
        svg += 'font-size="24" font-weight="bold" fill="#333">' + percentage.intValue() + '%</text>';
        
        // Range labels
        svg += '<text x="20" y="115" text-anchor="middle" font-family="Arial, sans-serif" ';
        svg += 'font-size="12" fill="#666">0</text>';
        svg += '<text x="180" y="115" text-anchor="middle" font-family="Arial, sans-serif" ';
        svg += 'font-size="12" fill="#666">100</text>';
        
        svg += '</svg>';
        
        return svg;
    }
    
    /**
     * Calculate score percentage for gauge display
     * @param totalScore Credit score (300-850 range)
     * @return Percentage (0-100)
     */
    private Decimal calculateScorePercentage(Decimal totalScore) {
        if (totalScore == null) return 0;
        
        Decimal minScore = 300;
        Decimal maxScore = 850;
        Decimal percentage = ((totalScore - minScore) / (maxScore - minScore)) * 100;
        return Math.max(0, Math.min(100, Math.round(percentage)));
    }
    
    /**
     * Create credit score attachments for email
     * @param account Customer account
     * @param creditScore Credit score record
     * @return List of email attachments
     */
    private List<Messaging.EmailFileAttachment> createCreditScoreAttachments(Account account, Credit_Score__c creditScore) {
        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        
        try {
            // Create PDF attachment with credit score report
            Messaging.EmailFileAttachment pdfAttachment = createCreditScorePdfAttachment(account, creditScore);
            if (pdfAttachment != null) {
                attachments.add(pdfAttachment);
            }
            
        } catch (Exception e) {
            System.debug('Error creating attachments: ' + e.getMessage());
            // Continue without attachments if there's an error
        }
        
        return attachments;
    }
    
    /**
     * Create PDF attachment with credit score visualization
     * @param account Customer account
     * @param creditScore Credit score record
     * @return PDF attachment
     */
    private Messaging.EmailFileAttachment createCreditScorePdfAttachment(Account account, Credit_Score__c creditScore) {
        try {
            // Generate HTML content for PDF
            String pdfHtml = generatePdfHtmlContent(account, creditScore);
            
            // Convert HTML to PDF (simplified approach)
            Blob pdfBlob = Blob.valueOf(pdfHtml); // In real implementation, use a PDF generation service
            
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('CreditScore_' + account.Name.replace(' ', '_') + '_' + 
                                 creditScore.Calculation_Date__c.format('yyyy-MM-dd') + '.html');
            attachment.setBody(pdfBlob);
            attachment.setContentType('text/html');
            
            return attachment;
            
        } catch (Exception e) {
            System.debug('Error creating PDF attachment: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Generate HTML content for PDF attachment
     * @param account Customer account
     * @param creditScore Credit score record
     * @return HTML content for PDF
     */
    private String generatePdfHtmlContent(Account account, Credit_Score__c creditScore) {
        String colorCode = getColorCode(creditScore.Score_Color__c);
        String scoreFormatted = CreditScoreUtils.formatScore(creditScore.Total_Score__c);
        Decimal scorePercentage = calculateScorePercentage(creditScore.Total_Score__c);
        String gaugeSvg = generateGaugeSvg(scorePercentage, colorCode);
        
        String html = '<!DOCTYPE html><html><head>';
        html += '<title>Credit Score Report - ' + account.Name + '</title>';
        html += '<style>';
        html += 'body { font-family: Arial, sans-serif; margin: 40px; background: white; }';
        html += '.header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }';
        html += '.gauge-section { text-align: center; margin: 40px 0; }';
        html += '.details-section { margin: 30px 0; }';
        html += '.breakdown-table { width: 100%; border-collapse: collapse; margin: 20px 0; }';
        html += '.breakdown-table th, .breakdown-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }';
        html += '.breakdown-table th { background-color: #f8f9fa; font-weight: bold; }';
        html += '.footer { margin-top: 50px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }';
        html += '</style></head><body>';
        
        // Header
        html += '<div class="header">';
        html += '<h1>Credit Score Report</h1>';
        html += '<h2>' + account.Name + '</h2>';
        html += '<p>Generated on ' + creditScore.Calculation_Date__c.format('MMMM d, yyyy') + '</p>';
        html += '</div>';
        
        // Gauge section
        html += '<div class="gauge-section">';
        html += gaugeSvg;
        html += '<h2 style="color: ' + colorCode + '; margin: 20px 0;">' + scoreFormatted + ' - ' + creditScore.Score_Status__c + '</h2>';
        html += '</div>';
        
        // Details section
        html += '<div class="details-section">';
        html += '<h3>Score Breakdown</h3>';
        html += '<table class="breakdown-table">';
        html += '<tr><th>Component</th><th>Score</th><th>Description</th></tr>';
        html += '<tr><td>Base Score</td><td>' + CreditScoreUtils.formatScore(creditScore.Base_Score__c) + '</td><td>Starting credit score baseline</td></tr>';
        html += '<tr><td>Profile Completion</td><td>' + CreditScoreUtils.formatScore(creditScore.Internal_Fields_Score__c) + '</td><td>Points from completed profile information</td></tr>';
        html += '<tr><td>Payment History</td><td>' + CreditScoreUtils.formatScore(creditScore.External_Billing_Score__c) + '</td><td>Points from on-time payment history</td></tr>';
        html += '<tr><td>Credit Bureau Data</td><td>' + CreditScoreUtils.formatScore(creditScore.API_Score__c) + '</td><td>Points from external credit bureau</td></tr>';
        html += '<tr style="font-weight: bold; background-color: #f8f9fa;"><td>Total Score</td><td>' + scoreFormatted + '</td><td>' + creditScore.Score_Status__c + '</td></tr>';
        html += '</table>';
        html += '</div>';
        
        // Improvement suggestions
        if (String.isNotBlank(creditScore.Missing_Fields__c)) {
            html += '<div class="details-section">';
            html += '<h3>Recommendations for Improvement</h3>';
            html += '<p>Complete the following profile fields to potentially improve your credit score:</p>';
            html += '<ul>';
            List<String> missingFields = creditScore.Missing_Fields__c.split(', ');
            for (String field : missingFields) {
                html += '<li>' + field + '</li>';
            }
            html += '</ul>';
            html += '</div>';
        }
        
        // Footer
        html += '<div class="footer">';
        html += '<p><strong>Universal Containers Credit Services</strong></p>';
        html += '<p>This report is confidential and intended solely for ' + account.Name + '.</p>';
        html += '<p>For questions about your credit score, please contact our customer service team.</p>';
        html += '</div>';
        
        html += '</body></html>';
        
        return html;
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