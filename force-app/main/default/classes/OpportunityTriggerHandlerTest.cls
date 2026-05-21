/**
 * @description Tests for OpportunityTriggerHandler - confirms the before-insert path populates the Reseller lookup.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
@isTest
private class OpportunityTriggerHandlerTest {

    // Seed a reseller for the trigger to match against
    @TestSetup
    static void makeData() {
        insert new Reseller__c(Name = 'Acme Resale', Company_Email__c = 'orders@acme.com');
    }

    @isTest
    static void triggerPopulatesResellerOnInsert() {
        Reseller__c reseller = [SELECT Id FROM Reseller__c LIMIT 1];
        // Inserting fires OpportunityTrigger -> handler.beforeInsert -> helper
        Opportunity opp = new Opportunity(Name = 'Insert Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(15), Reseller_Email__c = 'orders@acme.com');
        Test.startTest();
        insert opp;
        Test.stopTest();
        // The committed record should carry the populated lookup
        Opportunity result = [SELECT Reseller__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(reseller.Id, result.Reseller__c, 'Trigger should populate the Reseller lookup on insert');
    }

    @isTest
    static void triggerHandlesBulkInsert() {
        Reseller__c reseller = [SELECT Id FROM Reseller__c LIMIT 1];
        // Bulk insert to confirm the handler and helper are bulk-safe
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(Name = 'Bulk ' + i, StageName = 'Prospecting', CloseDate = Date.today().addDays(15), Reseller_Email__c = 'orders@acme.com'));
        }
        Test.startTest();
        insert opps;
        Test.stopTest();
        // Every record should be linked to the reseller
        System.assertEquals(200, [SELECT COUNT() FROM Opportunity WHERE Reseller__c = :reseller.Id], 'All bulk opportunities should be linked');
    }
}
