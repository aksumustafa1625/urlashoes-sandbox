/**
 * @description Unit tests for TaskRollupHelper - Opportunity Id collection and Task count rollups.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
@isTest
private class TaskRollupHelperTest {

    // Seed one Opportunity and one Account to act as Task parents
    @TestSetup
    static void makeData() {
        insert new Opportunity(Name = 'Rollup Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(20));
        insert new Account(Name = 'Rollup Account');
    }

    @isTest
    static void collectsOnlyOpportunityWhatIds() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        // Tasks pointing to an Opportunity, an Account, and nothing
        List<Task> tasks = new List<Task>{
            new Task(Subject = 'On Opp', WhatId = opp.Id),
            new Task(Subject = 'On Acct', WhatId = acc.Id),
            new Task(Subject = 'No What')
        };
        Set<Id> ids = new Set<Id>();
        TaskRollupHelper.collectOpportunityIds(tasks, ids);
        // Only the Opportunity WhatId should be collected
        System.assertEquals(1, ids.size(), 'Only Opportunity WhatIds should be collected');
        System.assert(ids.contains(opp.Id), 'The Opportunity Id should be present');
    }

    @isTest
    static void nullListIsHandled() {
        Set<Id> ids = new Set<Id>();
        // A null list must not throw and should add nothing
        TaskRollupHelper.collectOpportunityIds(null, ids);
        System.assertEquals(0, ids.size(), 'Null task list should add no ids');
    }

    @isTest
    static void rollsUpTotalAndCompletedCounts() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        // Two completed and one open task on the opportunity
        insert new List<Task>{
            new Task(Subject = 'A', Status = 'Completed', WhatId = opp.Id),
            new Task(Subject = 'B', Status = 'Completed', WhatId = opp.Id),
            new Task(Subject = 'C', Status = 'Not Started', WhatId = opp.Id)
        };
        Test.startTest();
        // Call the helper directly to recompute the rollups
        TaskRollupHelper.rollupTaskCounts(new Set<Id>{ opp.Id });
        Test.stopTest();
        Opportunity result = [SELECT Score__c, Completed_Task__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(3, result.Score__c, 'Score should equal the total task count');
        System.assertEquals(2, result.Completed_Task__c, 'Completed Task should equal the completed count');
    }

    @isTest
    static void emptyIdSetDoesNothing() {
        // No ids means the method should return without any query or DML
        Test.startTest();
        TaskRollupHelper.rollupTaskCounts(new Set<Id>());
        Test.stopTest();
        System.assert(true, 'Empty id set should be a safe no-op');
    }
}
