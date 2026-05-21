/**
 * @description Matches an Opportunity's reseller email to a Reseller's company email and sets the Reseller lookup.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
public with sharing class OpportunityResellerHelper {

    // Populate the Reseller lookup on each Opportunity whose reseller email matches a Reseller company email
    public static void populateResellerFromEmail(List<Opportunity> opportunities) {

        // Collect non-blank reseller emails, lower-cased for case-insensitive matching
        Set<String> resellerEmails = new Set<String>();
        for (Opportunity opp : opportunities) {
            if (String.isNotBlank(opp.Reseller_Email__c)) {
                resellerEmails.add(opp.Reseller_Email__c.toLowerCase());
            }
        }

        // No emails to match - nothing to do
        if (resellerEmails.isEmpty()) {
            return;
        }

        // Build a map of company email (lower-cased) -> Reseller Id from matching Resellers
        Map<String, Id> emailToResellerId = new Map<String, Id>();
        for (Reseller__c reseller : [
            SELECT Id, Company_Email__c
            FROM Reseller__c
            WHERE Company_Email__c IN :resellerEmails
        ]) {
            emailToResellerId.put(reseller.Company_Email__c.toLowerCase(), reseller.Id);
        }

        // Assign the matching Reseller to each Opportunity that has one
        for (Opportunity opp : opportunities) {
            if (String.isNotBlank(opp.Reseller_Email__c)) {
                Id resellerId = emailToResellerId.get(opp.Reseller_Email__c.toLowerCase());
                if (resellerId != null) {
                    opp.Reseller__c = resellerId;
                }
            }
        }
    }
}
