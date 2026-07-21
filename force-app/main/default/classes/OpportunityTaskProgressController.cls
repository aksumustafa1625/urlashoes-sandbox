/**
 * @description Provides aggregated Task progress data for the Opportunity Task Progress LWC.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
public with sharing class OpportunityTaskProgressController {

    // Fallback page size when the caller does not pass one
    private static final Integer DEFAULT_TOP_N = 10;

    // Returns the top N Opportunities ranked by total Task count (Score__c)
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getTopOpportunitiesByTasks(Integer topN) {
        // Guard against null or non-positive values
        Integer limitN = (topN == null || topN <= 0) ? DEFAULT_TOP_N : topN;
        // Only Opportunities that already have at least one Task
        return [
            SELECT Id, Name, Score__c, Completed_Task__c
            FROM Opportunity
            WHERE Score__c > 0
            ORDER BY Score__c DESC
            LIMIT :limitN
        ];
    }
}
