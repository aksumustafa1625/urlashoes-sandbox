/**
 * @description Task trigger; delegates to TaskTriggerHandler to roll up Task counts onto the related Opportunity.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
trigger TaskTrigger on Task (after insert, after update, after delete, after undelete) {
    // Single entry point - the framework dispatches to the matching context method
    new TaskTriggerHandler().run();
}
