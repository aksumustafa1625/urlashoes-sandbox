/**
 * @description Opportunity trigger handler (Kevin O'Hara framework); routes before-insert to the reseller helper.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    // New Opportunity records being inserted in this transaction
    private List<Opportunity> newOpportunities;

    // Constructor - capture Trigger.new so context methods can use it
    public OpportunityTriggerHandler() {
        this.newOpportunities = (List<Opportunity>) Trigger.new;
    }

    // Before insert - populate the Reseller lookup from the reseller email
    public override void beforeInsert() {
        OpportunityResellerHelper.populateResellerFromEmail(this.newOpportunities);
    }
}
