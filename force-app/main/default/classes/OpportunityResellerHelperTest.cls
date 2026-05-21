/**
 * @description Unit tests for OpportunityResellerHelper - matches a reseller email to the Reseller lookup.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
@isTest
private class OpportunityResellerHelperTest {

    // Seed a reseller whose company email the tests match against
    @TestSetup
    static void makeData() {
        insert new Reseller__c(Name = 'Acme Resale', Company_Email__c = 'match@test.com');
    }

    @isTest
    static void populatesLookupOnExactMatch() {
        Reseller__c reseller = [SELECT Id FROM Reseller__c LIMIT 1];
        // In-memory opportunity whose email matches the reseller company email
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(10), Reseller_Email__c = 'match@test.com')
        };
        Test.startTest();
        OpportunityResellerHelper.populateResellerFromEmail(opps);
        Test.stopTest();
        // Helper should set the lookup to the matching reseller
        System.assertEquals(reseller.Id, opps[0].Reseller__c, 'Lookup should be set on exact email match');
    }

    @isTest
    static void matchesIgnoringCase() {
        Reseller__c reseller = [SELECT Id FROM Reseller__c LIMIT 1];
        // Different letter case should still resolve to the same reseller
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(10), Reseller_Email__c = 'MATCH@test.COM')
        };
        OpportunityResellerHelper.populateResellerFromEmail(opps);
        System.assertEquals(reseller.Id, opps[0].Reseller__c, 'Matching should be case-insensitive');
    }

    @isTest
    static void leavesLookupNullWhenNoMatch() {
        // Email that no reseller owns
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(10), Reseller_Email__c = 'nobody@test.com')
        };
        OpportunityResellerHelper.populateResellerFromEmail(opps);
        System.assertEquals(null, opps[0].Reseller__c, 'Lookup should stay null when no reseller matches');
    }

    @isTest
    static void ignoresBlankEmail() {
        // No email provided means there is nothing to match
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(10))
        };
        OpportunityResellerHelper.populateResellerFromEmail(opps);
        System.assertEquals(null, opps[0].Reseller__c, 'Lookup should stay null when email is blank');
    }
}
