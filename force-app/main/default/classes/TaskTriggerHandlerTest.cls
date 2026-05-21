/**
 * @description Tests for TaskTriggerHandler - confirms Task insert/update/delete/undelete update the Opportunity rollups.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
@isTest
private class TaskTriggerHandlerTest {

    // Seed one Opportunity to attach tasks to
    @TestSetup
    static void makeData() {
        insert new Opportunity(Name = 'Task Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(25));
    }

    @isTest
    static void insertUpdatesRollups() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        // Insert two completed and one open task
        Test.startTest();
        insert new List<Task>{
            new Task(Subject = 'A', Status = 'Completed', WhatId = opp.Id),
            new Task(Subject = 'B', Status = 'Completed', WhatId = opp.Id),
            new Task(Subject = 'C', Status = 'Not Started', WhatId = opp.Id)
        };
        Test.stopTest();
        Opportunity result = [SELECT Score__c, Completed_Task__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(3, result.Score__c, 'Score should be 3 after inserting 3 tasks');
        System.assertEquals(2, result.Completed_Task__c, 'Completed should be 2 after inserting 2 completed tasks');
    }

    @isTest
    static void completingTaskUpdatesCompletedCount() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        // Start with one open task
        Task t = new Task(Subject = 'C', Status = 'Not Started', WhatId = opp.Id);
        insert t;
        Test.startTest();
        // Completing the task should raise the completed count
        t.Status = 'Completed';
        update t;
        Test.stopTest();
        Opportunity result = [SELECT Score__c, Completed_Task__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(1, result.Score__c, 'Score should remain 1');
        System.assertEquals(1, result.Completed_Task__c, 'Completed should become 1 after the task is completed');
    }

    @isTest
    static void deletingTaskUpdatesRollups() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        // Two completed tasks, then delete one
        List<Task> tasks = new List<Task>{
            new Task(Subject = 'A', Status = 'Completed', WhatId = opp.Id),
            new Task(Subject = 'B', Status = 'Completed', WhatId = opp.Id)
        };
        insert tasks;
        Test.startTest();
        delete tasks[0];
        Test.stopTest();
        Opportunity result = [SELECT Score__c, Completed_Task__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(1, result.Score__c, 'Score should drop to 1 after deleting one task');
        System.assertEquals(1, result.Completed_Task__c, 'Completed should drop to 1 after deleting one completed task');
    }

    @isTest
    static void undeleteRestoresRollups() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        // Insert then delete a completed task
        Task t = new Task(Subject = 'A', Status = 'Completed', WhatId = opp.Id);
        insert t;
        delete t;
        Test.startTest();
        // Undeleting should restore the counts
        undelete t;
        Test.stopTest();
        Opportunity result = [SELECT Score__c, Completed_Task__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(1, result.Score__c, 'Score should be 1 after undelete');
        System.assertEquals(1, result.Completed_Task__c, 'Completed should be 1 after undelete');
    }
}
