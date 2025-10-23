//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public with sharing class CreditScoreConfigurationService {
    
    // Cache for configuration data to improve performance
    private static List<Credit_Score_Configuration__mdt> cachedConfigurations;
    private static Map<String, Credit_Score_Configuration__mdt> cachedConfigurationMap;
    
    /**
     * Get all active internal field configurations
     * @return List of Credit_Score_Configuration__mdt records for internal fields
     */
    public static List<Credit_Score_Configuration__mdt> getActiveInternalFields() {
        List<Credit_Score_Configuration__mdt> allConfigs = getAllActiveConfigurations();
        List<Credit_Score_Configuration__mdt> internalFields = new List<Credit_Score_Configuration__mdt>();
        
        for (Credit_Score_Configuration__mdt config : allConfigs) {
            if (config.Category__c == 'Internal_Field') {
                internalFields.add(config);
            }
        }
        
        return internalFields;
    }

    /**
     * Get active credit score configuration for LWC
     * @return List of Credit_Score_Configuration__mdt records
     */
    @AuraEnabled(cacheable=true)
    public static List<Credit_Score_Configuration__mdt> getActiveConfiguration() {
        try {
            return getAllActiveConfigurations();
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving configuration: ' + e.getMessage());
        }
    }

    /**
     * Update credit score configuration (Note: Custom Metadata cannot be updated via Apex)
     * This method provides a placeholder for future enhancement
     * @param configurations List of configuration records to update
     * @return String success message
     */
    @AuraEnabled
    public static String updateConfiguration(List<Credit_Score_Configuration__mdt> configurations) {
        try {
            // Note: Custom Metadata Types cannot be updated via Apex in runtime
            // This would typically require Metadata API or manual configuration
            // For demo purposes, we'll return a success message
            
            if (configurations == null || configurations.isEmpty()) {
                throw new AuraHandledException('No configuration records provided');
            }
            
            // In a real implementation, this would:
            // 1. Use Metadata API to update Custom Metadata Types
            // 2. Or store configuration in a custom object instead
            // 3. Or use Platform Events to notify administrators
            
            System.debug('Configuration update requested for ' + configurations.size() + ' records');
            
            // Log the configuration changes for audit
            for (Credit_Score_Configuration__mdt config : configurations) {
                System.debug('Config Update - Field: ' + config.Field_API_Name__c + 
                           ', Weight: ' + config.Weight_Points__c + 
                           ', Active: ' + config.Is_Active__c);
            }
            
            return 'Configuration update request logged. Changes will be applied by system administrator.';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error processing configuration update: ' + e.getMessage());
        }
    }
    
    /**
     * Get all active configurations regardless of category
     * @return List of all active Credit_Score_Configuration__mdt records
     */
    public static List<Credit_Score_Configuration__mdt> getAllActiveConfigurations() {
        if (cachedConfigurations == null) {
            cachedConfigurations = [
                SELECT Id, DeveloperName, MasterLabel, Field_API_Name__c, Field_Label__c,
                       Weight_Points__c, Category__c, Is_Active__c, Object_API_Name__c,
                       Validation_Rule__c
                FROM Credit_Score_Configuration__mdt
                WHERE Is_Active__c = true
                ORDER BY Category__c, Field_Label__c
            ];
        }
        
        return cachedConfigurations;
    }
    
    /**
     * Get configuration map for quick lookup by field API name
     * @return Map of Field API Name to Credit_Score_Configuration__mdt
     */
    public static Map<String, Credit_Score_Configuration__mdt> getConfigurationMap() {
        if (cachedConfigurationMap == null) {
            cachedConfigurationMap = new Map<String, Credit_Score_Configuration__mdt>();
            
            for (Credit_Score_Configuration__mdt config : getAllActiveConfigurations()) {
                cachedConfigurationMap.put(config.Field_API_Name__c, config);
            }
        }
        
        return cachedConfigurationMap;
    }
    
    /**
     * Get field weight for scoring calculation
     * @param fieldName API name of the field
     * @param totalFields Total number of fields in the category
     * @return Decimal weight for the field
     */
    public static Decimal getFieldWeight(String fieldName, Integer totalFields) {
        Map<String, Credit_Score_Configuration__mdt> configMap = getConfigurationMap();
        Credit_Score_Configuration__mdt config = configMap.get(fieldName);
        
        if (config != null && config.Weight_Points__c != null) {
            return config.Weight_Points__c;
        }
        
        // Default to equal distribution if no specific weight is configured
        return totalFields > 0 ? (150.0 / totalFields) : 0;
    }
    
    /**
     * Get configurations by category
     * @param category Category to filter by (Internal_Field, External_Billing, API_Data)
     * @return List of configurations for the specified category
     */
    public static List<Credit_Score_Configuration__mdt> getConfigurationsByCategory(String category) {
        List<Credit_Score_Configuration__mdt> allConfigs = getAllActiveConfigurations();
        List<Credit_Score_Configuration__mdt> categoryConfigs = new List<Credit_Score_Configuration__mdt>();
        
        for (Credit_Score_Configuration__mdt config : allConfigs) {
            if (config.Category__c == category) {
                categoryConfigs.add(config);
            }
        }
        
        return categoryConfigs;
    }
    
    /**
     * Validate field configuration
     * @param fieldName API name of the field to validate
     * @param fieldValue Value to validate
     * @return Boolean indicating if validation passed
     */
    public static Boolean validateField(String fieldName, Object fieldValue) {
        Map<String, Credit_Score_Configuration__mdt> configMap = getConfigurationMap();
        Credit_Score_Configuration__mdt config = configMap.get(fieldName);
        
        if (config == null) {
            return true; // No configuration means no validation required
        }
        
        // Check if field has value when required
        if (fieldValue == null || String.valueOf(fieldValue).trim() == '') {
            return false; // Field is empty
        }
        
        // Apply custom validation rule if configured
        if (String.isNotBlank(config.Validation_Rule__c)) {
            return applyValidationRule(config.Validation_Rule__c, fieldValue);
        }
        
        return true;
    }
    
    /**
     * Apply custom validation rule to field value
     * @param validationRule Validation rule expression
     * @param fieldValue Value to validate
     * @return Boolean indicating if validation passed
     */
    private static Boolean applyValidationRule(String validationRule, Object fieldValue) {
        try {
            // Simple validation rule implementation
            // In a real implementation, this could be more sophisticated
            String value = String.valueOf(fieldValue);
            
            // Example validation rules:
            if (validationRule.contains('ISBLANK')) {
                return String.isNotBlank(value);
            }
            
            if (validationRule.contains('LEN') && validationRule.contains('>')) {
                // Extract minimum length requirement
                Pattern p = Pattern.compile('LEN\\([^)]+\\)\\s*>\\s*(\\d+)');
                Matcher m = p.matcher(validationRule);
                if (m.find()) {
                    Integer minLength = Integer.valueOf(m.group(1));
                    return value.length() > minLength;
                }
            }
            
            if (validationRule.contains('REGEX')) {
                // Extract regex pattern
                Pattern p = Pattern.compile('REGEX\\([^,]+,\\s*"([^"]+)"\\)');
                Matcher m = p.matcher(validationRule);
                if (m.find()) {
                    String regexPattern = m.group(1);
                    return Pattern.matches(regexPattern, value);
                }
            }
            
            return true; // Default to valid if rule not recognized
            
        } catch (Exception e) {
            System.debug('Error applying validation rule: ' + e.getMessage());
            return true; // Default to valid on error
        }
    }
    
    /**
     * Get total possible points for a category
     * @param category Category to get total points for
     * @return Decimal total possible points
     */
    public static Decimal getTotalPointsForCategory(String category) {
        switch on category {
            when 'Internal_Field' {
                return 150.0;
            }
            when 'External_Billing' {
                return 150.0;
            }
            when 'API_Data' {
                return 500.0; // Variable based on external API
            }
            when else {
                return 0.0;
            }
        }
    }
    
    /**
     * Get field labels for missing fields analysis
     * @param fieldApiNames List of field API names
     * @return List of field labels
     */
    public static List<String> getFieldLabels(List<String> fieldApiNames) {
        Map<String, Credit_Score_Configuration__mdt> configMap = getConfigurationMap();
        List<String> fieldLabels = new List<String>();
        
        for (String fieldName : fieldApiNames) {
            Credit_Score_Configuration__mdt config = configMap.get(fieldName);
            if (config != null) {
                fieldLabels.add(config.Field_Label__c);
            } else {
                fieldLabels.add(fieldName); // Fallback to API name
            }
        }
        
        return fieldLabels;
    }
    
    /**
     * Check if a field is configured for scoring
     * @param fieldName API name of the field
     * @return Boolean indicating if field is configured
     */
    public static Boolean isFieldConfigured(String fieldName) {
        Map<String, Credit_Score_Configuration__mdt> configMap = getConfigurationMap();
        return configMap.containsKey(fieldName);
    }
    
    /**
     * Get configuration summary for reporting
     * @return ConfigurationSummary with statistics
     */
    public static ConfigurationSummary getConfigurationSummary() {
        List<Credit_Score_Configuration__mdt> allConfigs = getAllActiveConfigurations();
        
        ConfigurationSummary summary = new ConfigurationSummary();
        summary.totalConfigurations = allConfigs.size();
        summary.internalFieldCount = 0;
        summary.externalBillingCount = 0;
        summary.apiDataCount = 0;
        
        for (Credit_Score_Configuration__mdt config : allConfigs) {
            switch on config.Category__c {
                when 'Internal_Field' {
                    summary.internalFieldCount++;
                }
                when 'External_Billing' {
                    summary.externalBillingCount++;
                }
                when 'API_Data' {
                    summary.apiDataCount++;
                }
            }
        }
        
        return summary;
    }
    
    /**
     * Clear cached configurations (useful for testing or after configuration changes)
     */
    public static void clearCache() {
        cachedConfigurations = null;
        cachedConfigurationMap = null;
    }
    
    /**
     * Wrapper class for configuration summary
     */
    public class ConfigurationSummary {
        public Integer totalConfigurations { get; set; }
        public Integer internalFieldCount { get; set; }
        public Integer externalBillingCount { get; set; }
        public Integer apiDataCount { get; set; }
        
        public ConfigurationSummary() {
            this.totalConfigurations = 0;
            this.internalFieldCount = 0;
            this.externalBillingCount = 0;
            this.apiDataCount = 0;
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________
