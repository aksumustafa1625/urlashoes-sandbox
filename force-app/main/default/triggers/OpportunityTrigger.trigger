/**
 * @description Opportunity trigger; delegates all logic to OpportunityTriggerHandler.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
trigger OpportunityTrigger on Opportunity (before insert) {
    // Single entry point - dispatch the current context via the trigger framework
    new OpportunityTriggerHandler().run();
}
