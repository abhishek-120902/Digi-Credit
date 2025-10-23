//_______________This Code was generated using GenAI tool : Codify, Please check for accuracy_______________

public with sharing class CreditScoreUtils {
    
    // Score range constants
    private static final Decimal EXCELLENT_THRESHOLD = 600;
    private static final Decimal GOOD_THRESHOLD = 450;
    private static final Decimal POOR_THRESHOLD = 300;
    
    /**
     * Determine credit score status based on total score
     * @param totalScore Total calculated credit score
     * @return String status (Poor, Good, Excellent)
     */
    public static String determineScoreStatus(Decimal totalScore) {
        if (totalScore == null) {
            return 'Unknown';
        }
        
        if (totalScore >= EXCELLENT_THRESHOLD) {
            return 'Excellent';
        } else if (totalScore >= GOOD_THRESHOLD) {
            return 'Good';
        } else {
            return 'Poor';
        }
    }
    
    /**
     * Get color coding for credit score visualization
     * @param totalScore Total calculated credit score
     * @return String color (Red, Yellow, Green)
     */
    public static String getScoreColor(Decimal totalScore) {
        if (totalScore == null) {
            return 'Gray';
        }
        
        if (totalScore >= EXCELLENT_THRESHOLD) {
            return 'Green';
        } else if (totalScore >= GOOD_THRESHOLD) {
            return 'Yellow';
        } else {
            return 'Red';
        }
    }
    
    /**
     * Analyze missing fields for improvement suggestions
     * @param customer Account record with customer data
     * @param configs List of active field configurations
     * @return List of missing field labels
     */
    public static List<String> analyzeMissingFields(Account customer, List<Credit_Score_Configuration__mdt> configs) {
        List<String> missingFields = new List<String>();
        
        if (customer == null || configs == null) {
            return missingFields;
        }
        
        for (Credit_Score_Configuration__mdt config : configs) {
            try {
                Object fieldValue = customer.get(config.Field_API_Name__c);
                
                if (fieldValue == null || String.valueOf(fieldValue).trim() == '') {
                    missingFields.add(config.Field_Label__c);
                }
            } catch (Exception e) {
                System.debug('Error analyzing field ' + config.Field_API_Name__c + ': ' + e.getMessage());
                // Continue with other fields
            }
        }
        
        return missingFields;
    }
    
    /**
     * Generate detailed calculation breakdown for audit purposes
     * @param components ScoreComponents with all calculated values
     * @return JSON string with calculation details
     */
    public static String generateCalculationDetails(CreditScoreCalculationService.ScoreComponents components) {
        if (components == null) {
            return '{}';
        }
        
        Map<String, Object> details = new Map<String, Object>();
        details.put('calculationDate', System.now());
        details.put('baseScore', components.baseScore);
        details.put('internalFieldsScore', components.internalFieldsScore);
        details.put('billingScore', components.billingScore);
        details.put('apiScore', components.apiScore);
        details.put('totalScore', components.totalScore);
        details.put('scoreStatus', components.scoreStatus);
        details.put('scoreColor', components.scoreColor);
        details.put('missingFieldsCount', components.missingFields != null ? components.missingFields.size() : 0);
        
        // Add breakdown percentages
        if (components.totalScore > 0) {
            details.put('baseScorePercentage', (components.baseScore / components.totalScore) * 100);
            details.put('internalFieldsPercentage', (components.internalFieldsScore / components.totalScore) * 100);
            details.put('billingPercentage', (components.billingScore / components.totalScore) * 100);
            details.put('apiPercentage', (components.apiScore / components.totalScore) * 100);
        }
        
        return JSON.serialize(details);
    }
    
    /**
     * Calculate improvement potential for missing fields
     * @param missingFields List of missing field labels
     * @param totalActiveFields Total number of active fields in configuration
     * @return Decimal potential points that could be gained
     */
    public static Decimal calculateImprovementPotential(List<String> missingFields, Integer totalActiveFields) {
        if (missingFields == null || missingFields.isEmpty() || totalActiveFields == 0) {
            return 0;
        }
        
        Decimal pointsPerField = 150.0 / totalActiveFields;
        return missingFields.size() * pointsPerField;
    }
    
    /**
     * Format score for display with proper decimal places
     * @param score Score value to format
     * @return Formatted score string
     */
    public static String formatScore(Decimal score) {
        if (score == null) {
            return '0';
        }
        
        return String.valueOf(score.setScale(0));
    }
    
    /**
     * Get score range information for UI display
     * @return List of ScoreRange objects with range details
     */
    public static List<ScoreRange> getScoreRanges() {
        List<ScoreRange> ranges = new List<ScoreRange>();
        
        ranges.add(new ScoreRange('Poor', 300, 449, 'Red', 'Needs significant improvement'));
        ranges.add(new ScoreRange('Good', 450, 599, 'Yellow', 'Acceptable credit standing'));
        ranges.add(new ScoreRange('Excellent', 600, 850, 'Green', 'Outstanding credit profile'));
        
        return ranges;
    }
    
    /**
     * Validate score is within acceptable range
     * @param score Score to validate
     * @return Boolean indicating if score is valid
     */
    public static Boolean isValidScore(Decimal score) {
        return score != null && score >= POOR_THRESHOLD && score <= 850;
    }
    
    /**
     * Calculate score improvement percentage
     * @param oldScore Previous score
     * @param newScore Current score
     * @return Decimal percentage improvement (positive) or decline (negative)
     */
    public static Decimal calculateScoreImprovement(Decimal oldScore, Decimal newScore) {
        if (oldScore == null || newScore == null || oldScore == 0) {
            return 0;
        }
        
        return ((newScore - oldScore) / oldScore) * 100;
    }
    
    /**
     * Get improvement recommendations based on missing fields
     * @param missingFields List of missing field labels
     * @param totalActiveFields Total active fields
     * @return List of ImprovementRecommendation objects
     */
    public static List<ImprovementRecommendation> getImprovementRecommendations(List<String> missingFields, Integer totalActiveFields) {
        List<ImprovementRecommendation> recommendations = new List<ImprovementRecommendation>();
        
        if (missingFields == null || missingFields.isEmpty()) {
            return recommendations;
        }
        
        Decimal pointsPerField = totalActiveFields > 0 ? (150.0 / totalActiveFields) : 0;
        
        for (String fieldLabel : missingFields) {
            ImprovementRecommendation rec = new ImprovementRecommendation();
            rec.action = 'Complete your ' + fieldLabel + ' information';
            rec.potentialPoints = pointsPerField;
            rec.priority = determinePriority(fieldLabel);
            rec.category = 'Profile Completion';
            
            recommendations.add(rec);
        }
        
        return recommendations;
    }
    
    /**
     * Determine priority level for field completion
     * @param fieldLabel Label of the field
     * @return String priority level (High, Medium, Low)
     */
    private static String determinePriority(String fieldLabel) {
        // High priority fields
        Set<String> highPriorityFields = new Set<String>{'Phone', 'Age', 'Address'};
        
        for (String highPriorityField : highPriorityFields) {
            if (fieldLabel.containsIgnoreCase(highPriorityField)) {
                return 'High';
            }
        }
        
        return 'Medium'; // Default to medium priority
    }
    
    /**
     * Generate score trend analysis
     * @param scores List of historical Credit_Score__c records
     * @return ScoreTrend object with trend analysis
     */
    public static ScoreTrend analyzeScoreTrend(List<Credit_Score__c> scores) {
        ScoreTrend trend = new ScoreTrend();
        
        if (scores == null || scores.size() < 2) {
            trend.trendDirection = 'Insufficient Data';
            return trend;
        }
        
        // Sort by calculation date
        scores.sort();
        
        Credit_Score__c latestScore = scores[scores.size() - 1];
        Credit_Score__c previousScore = scores[scores.size() - 2];
        
        trend.currentScore = latestScore.Total_Score__c;
        trend.previousScore = previousScore.Total_Score__c;
        trend.scoreChange = trend.currentScore - trend.previousScore;
        trend.percentageChange = calculateScoreImprovement(trend.previousScore, trend.currentScore);
        
        if (trend.scoreChange > 0) {
            trend.trendDirection = 'Improving';
        } else if (trend.scoreChange < 0) {
            trend.trendDirection = 'Declining';
        } else {
            trend.trendDirection = 'Stable';
        }
        
        return trend;
    }
    
    /**
     * Wrapper class for score range information
     */
    public class ScoreRange {
        public String status { get; set; }
        public Integer minScore { get; set; }
        public Integer maxScore { get; set; }
        public String color { get; set; }
        public String description { get; set; }
        
        public ScoreRange(String status, Integer minScore, Integer maxScore, String color, String description) {
            this.status = status;
            this.minScore = minScore;
            this.maxScore = maxScore;
            this.color = color;
            this.description = description;
        }
    }
    
    /**
     * Wrapper class for improvement recommendations
     */
    public class ImprovementRecommendation {
        public String action { get; set; }
        public Decimal potentialPoints { get; set; }
        public String priority { get; set; }
        public String category { get; set; }
    }
    
    /**
     * Wrapper class for score trend analysis
     */
    public class ScoreTrend {
        public Decimal currentScore { get; set; }
        public Decimal previousScore { get; set; }
        public Decimal scoreChange { get; set; }
        public Decimal percentageChange { get; set; }
        public String trendDirection { get; set; }
        
        public ScoreTrend() {
            this.currentScore = 0;
            this.previousScore = 0;
            this.scoreChange = 0;
            this.percentageChange = 0;
            this.trendDirection = 'Unknown';
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________
