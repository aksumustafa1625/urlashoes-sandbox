/**
 * @description Rolls up Task counts onto Opportunity: Score__c = total Tasks, Completed_Task__c = completed Tasks.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
public with sharing class TaskRollupHelper {

    // Key prefix that identifies an Opportunity record Id
    private static final String OPPORTUNITY_PREFIX = '006';

    // Status value that marks a Task as completed
    private static final String COMPLETED_STATUS = 'Completed';

    // Add the Opportunity Ids referenced by these Tasks (via WhatId) to the given set
    public static void collectOpportunityIds(List<Task> tasks, Set<Id> opportunityIds) {
        if (tasks == null) {
            return;
        }
        for (Task t : tasks) {
            // Only Tasks whose WhatId points to an Opportunity are relevant
            if (t.WhatId != null && String.valueOf(t.WhatId).startsWith(OPPORTUNITY_PREFIX)) {
                opportunityIds.add(t.WhatId);
            }
        }
    }

    // Recalculate the total and completed Task counts for the given Opportunities and update them
    public static void rollupTaskCounts(Set<Id> opportunityIds) {
        if (opportunityIds.isEmpty()) {
            return;
        }

        // Total Task count per Opportunity -> Score__c
        Map<Id, Integer> totalByOpp = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT WhatId wId, COUNT(Id) total
            FROM Task
            WHERE WhatId IN :opportunityIds
            GROUP BY WhatId
        ]) {
            totalByOpp.put((Id) ar.get('wId'), (Integer) ar.get('total'));
        }

        // Completed Task count per Opportunity -> Completed_Task__c
        Map<Id, Integer> completedByOpp = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT WhatId wId, COUNT(Id) total
            FROM Task
            WHERE WhatId IN :opportunityIds AND Status = :COMPLETED_STATUS
            GROUP BY WhatId
        ]) {
            completedByOpp.put((Id) ar.get('wId'), (Integer) ar.get('total'));
        }

        // Build the Opportunity updates, defaulting to 0 when no Tasks remain
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Id opportunityId : opportunityIds) {
            Integer total = totalByOpp.containsKey(opportunityId) ? totalByOpp.get(opportunityId) : 0;
            Integer completed = completedByOpp.containsKey(opportunityId) ? completedByOpp.get(opportunityId) : 0;
            opportunitiesToUpdate.add(new Opportunity(
                Id = opportunityId,
                Score__c = total,
                Completed_Task__c = completed
            ));
        }

        // Single DML to persist all rollups
        update opportunitiesToUpdate;
    }
}
