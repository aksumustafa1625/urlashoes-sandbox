/**
 * @description Tests for OpportunityTaskProgressController.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
@isTest
private class OpportunityTaskProgressControllerTest {

    // Seed three Opportunities with different task volumes
    @TestSetup
    static void makeData() {
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'High Tasks', StageName = 'Prospecting', CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Mid Tasks',  StageName = 'Prospecting', CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Low Tasks',  StageName = 'Prospecting', CloseDate = Date.today().addDays(30))
        };
        insert opps;
        // High: 5 tasks (3 completed), Mid: 3 tasks (1 completed), Low: 1 task (0 completed)
        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 5; i++) tasks.add(new Task(Subject = 'H'+i, Status = i < 3 ? 'Completed' : 'Not Started', WhatId = opps[0].Id));
        for (Integer i = 0; i < 3; i++) tasks.add(new Task(Subject = 'M'+i, Status = i < 1 ? 'Completed' : 'Not Started', WhatId = opps[1].Id));
        tasks.add(new Task(Subject = 'L0', Status = 'Not Started', WhatId = opps[2].Id));
        insert tasks;
    }

    @isTest
    static void returnsTopNSortedDescending() {
        Test.startTest();
        List<Opportunity> result = OpportunityTaskProgressController.getTopOpportunitiesByTasks(10);
        Test.stopTest();
        // All three opportunities have tasks so all should come back
        System.assertEquals(3, result.size(), 'All opportunities with tasks should be returned');
        // Ordered by Score__c DESC -> High, Mid, Low
        System.assertEquals('High Tasks', result[0].Name, 'Highest Score should come first');
        System.assertEquals('Low Tasks',  result[2].Name, 'Lowest Score should come last');
    }

    @isTest
    static void respectsTopNLimit() {
        // Asking for 1 should return only the top one
        List<Opportunity> result = OpportunityTaskProgressController.getTopOpportunitiesByTasks(1);
        System.assertEquals(1, result.size(), 'Should return only the requested number');
        System.assertEquals('High Tasks', result[0].Name, 'Top 1 should be the highest');
    }

    @isTest
    static void defaultsWhenTopNIsNull() {
        // Null falls back to default of 10 -> all three returned
        List<Opportunity> result = OpportunityTaskProgressController.getTopOpportunitiesByTasks(null);
        System.assertEquals(3, result.size(), 'Null should fall back to default');
    }

    @isTest
    static void excludesOpportunitiesWithoutTasks() {
        // A new opportunity with no tasks should be filtered out
        insert new Opportunity(Name = 'No Tasks', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        List<Opportunity> result = OpportunityTaskProgressController.getTopOpportunitiesByTasks(10);
        for (Opportunity o : result) {
            System.assertNotEquals('No Tasks', o.Name, 'Opportunities without tasks should be excluded');
        }
    }
}
