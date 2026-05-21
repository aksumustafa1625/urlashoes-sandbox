/**
 * @description Task trigger handler (Kevin O'Hara framework); recalculates Opportunity Task rollups on every relevant event.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
public with sharing class TaskTriggerHandler extends TriggerHandler {

    // Tasks after the change (null on delete)
    private List<Task> newTasks;

    // Tasks before the change (null on insert/undelete)
    private List<Task> oldTasks;

    // Constructor - capture the trigger collections for the context methods
    public TaskTriggerHandler() {
        this.newTasks = (List<Task>) Trigger.new;
        this.oldTasks = (List<Task>) Trigger.old;
    }

    // After insert - a new (possibly completed) Task may change the counts
    public override void afterInsert() {
        recalculate();
    }

    // After update - status or related Opportunity may have changed
    public override void afterUpdate() {
        recalculate();
    }

    // After delete - a removed Task lowers the counts
    public override void afterDelete() {
        recalculate();
    }

    // After undelete - a restored Task raises the counts
    public override void afterUndelete() {
        recalculate();
    }

    // Collect every affected Opportunity Id (from new and old) and roll up its Task counts
    private void recalculate() {
        Set<Id> opportunityIds = new Set<Id>();
        TaskRollupHelper.collectOpportunityIds(this.newTasks, opportunityIds);
        TaskRollupHelper.collectOpportunityIds(this.oldTasks, opportunityIds);
        TaskRollupHelper.rollupTaskCounts(opportunityIds);
    }
}
