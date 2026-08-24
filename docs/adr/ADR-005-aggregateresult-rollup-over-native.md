# ADR-005: Task counts roll up through one aggregate query, because a native roll-up is impossible

## Status

**Accepted**

## Date

2026-05-21

## Author

Mustafa Aksu

## Context

`Opportunity.Score__c` holds the number of related Tasks and
`Opportunity.Completed_Task__c` holds how many of them are complete.

A roll-up summary field is the correct Salesforce answer to "count the
children" — declarative, maintained by the platform, no code to test. It is not
available here. Roll-up summary fields require a **master-detail** relationship,
and Task relates to Opportunity through `WhatId`, a **polymorphic lookup** that
can point at an Account, a Case, an Opportunity or several other objects. There
is no master-detail to declare, so there is no roll-up summary to create.

That leaves code, and the way code gets this wrong is well known: query the
Tasks for each Opportunity in a loop. That is correct for one record and fails
on the 101st, which is the standard shape of a bulkification bug.

## Decision

Recalculate both counts for the whole affected set with **two aggregate
queries**, one grouped scan per metric:

```apex
SELECT WhatId wId, COUNT(Id) total
FROM Task
WHERE WhatId IN :opportunityIds
GROUP BY WhatId
```

`TaskRollupHelper.rollupTaskCounts` takes a `Set<Id>` and issues a fixed number
of queries regardless of set size, then updates the Opportunities in one DML
statement. The counts are recomputed from the current data rather than
incremented, so a delete, an undelete or a data load converges to the truth on
the next trigger run.

## Alternatives Considered

- **Roll-up summary field.** Not available — no master-detail relationship
  exists, and the polymorphic `WhatId` makes one impossible.
- **A third-party declarative roll-up tool (DLRS).** Rejected: a managed
  dependency for two integer fields, in a project whose point is to show the
  underlying pattern rather than to install one.
- **Incrementing and decrementing on each trigger event.** Rejected: it drifts.
  Any path that bypasses the trigger — Data Loader with the handler bypassed,
  a recycle-bin restore — leaves the number permanently wrong, with no
  self-correction.
- **A scheduled recalculation job.** Rejected: the dashboard would be correct
  only between runs, and staleness is the one thing a progress indicator cannot
  afford.

## Consequences

- Query count is constant in the number of Opportunities touched, so a 200-record
  data load costs the same two queries as a single edit.
- Recomputation-from-source means the fields are self-healing.
- The logic lives in a helper taking plain collections, so its tests assert on
  the aggregation without inserting Opportunities through the trigger.
- Cost is a small amount of code where a declarative field would have sufficed
  on a differently-shaped object — which is exactly the trade-off the ADR
  records.

## References

- `force-app/main/default/classes/TaskRollupHelper.cls`
- `force-app/main/default/classes/TaskRollupHelperTest.cls`
- `force-app/main/default/triggers/TaskTrigger.trigger`
