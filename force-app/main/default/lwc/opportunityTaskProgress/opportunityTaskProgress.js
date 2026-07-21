/**
 * @description LWC showing KPI cards (total/completed/percentage) and a Top-N Opportunity progress list.
 * @author      Mustafa Aksu
 * @date        2026-05-21
 */
import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTopOpportunitiesByTasks from '@salesforce/apex/OpportunityTaskProgressController.getTopOpportunitiesByTasks';

export default class OpportunityTaskProgress extends LightningElement {

    // Card title - configurable from Lightning App Builder
    @api title = 'Task Progress';

    // Number of opportunities to list - configurable from Lightning App Builder
    @api topN = 10;

    // Stored wire result so we can call refreshApex on it
    wiredResult;

    // Decorated rows for the template (id, name, total, completed, pct, barStyle)
    opportunities = [];

    // Error placeholder for the template
    error;

    // Wire the Apex method - rerun automatically when topN changes
    @wire(getTopOpportunitiesByTasks, { topN: '$topN' })
    wiredOpps(result) {
        this.wiredResult = result;
        if (result.data) {
            // Decorate each row with completion percentage and an inline style for the progress bar
            this.opportunities = result.data.map(o => {
                const total = o.Score__c || 0;
                const completed = o.Completed_Task__c || 0;
                const pct = total > 0 ? Math.round((completed / total) * 100) : 0;
                return {
                    id: o.Id,
                    name: o.Name,
                    total,
                    completed,
                    pct,
                    barStyle: `width: ${pct}%`
                };
            });
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.opportunities = [];
        }
    }

    // KPI: total task count across all listed opportunities
    get totalTasks() {
        return this.opportunities.reduce((sum, o) => sum + o.total, 0);
    }

    // KPI: completed task count across all listed opportunities
    get totalCompleted() {
        return this.opportunities.reduce((sum, o) => sum + o.completed, 0);
    }

    // KPI: overall completion percentage
    get overallPct() {
        return this.totalTasks > 0 ? Math.round((this.totalCompleted / this.totalTasks) * 100) : 0;
    }

    // Whether we have at least one row to render
    get hasData() {
        return this.opportunities.length > 0;
    }

    // Manual refresh button handler
    handleRefresh() {
        refreshApex(this.wiredResult);
    }
}
