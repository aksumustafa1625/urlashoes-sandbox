# ADR-006: Opportunity Tasks are identified by key prefix rather than by describe or query

## Status

**Accepted**

## Date

2026-05-21

## Author

Mustafa Aksu

## Context

`Task.WhatId` is polymorphic. A Task in the trigger set may be related to an
Account, a Case, a Contract or an Opportunity, and only the Opportunity ones are
relevant to the roll-up. The filter therefore runs on every Task in every insert
and update — including bulk loads that touch thousands of records unrelated to
Opportunities.

The options are to ask the platform what the Id refers to (`getSObjectType()`
via describe), to query, or to read the Id itself.

## Decision

Test the first three characters of the Id against the Opportunity key prefix:

```apex
private static final String OPPORTUNITY_PREFIX = '006';
...
if (t.WhatId != null && String.valueOf(t.WhatId).startsWith(OPPORTUNITY_PREFIX)) {
    opportunityIds.add(t.WhatId);
}
```

Salesforce key prefixes are stable per standard object, and `006` has meant
Opportunity for the life of the platform. The check is a string comparison with
no query, no describe call and no governor cost.

## Alternatives Considered

- **`t.WhatId.getSObjectType() == Opportunity.SObjectType`.** More readable and
  self-documenting, and it is the right choice in code that must survive a
  reviewer who does not recognise `006`. Rejected here because describe
  information is consumed per transaction and the filter runs over every Task in
  every bulk operation; the constant carries the meaning that the describe call
  would have made explicit.
- **Querying the Tasks back with a typed `WHERE`.** Rejected: an extra query to
  learn something the Id already states.
- **Not filtering, and letting the aggregate query return nothing.** Rejected:
  it would put non-Opportunity Ids into the bind set and do work proportional to
  unrelated data.

## Consequences

- The filter is O(1) per Task with no platform call.
- It depends on an undocumented-but-stable platform convention. The prefix is a
  named constant precisely so that dependency is stated once and findable.
- This applies only to **standard** objects. Custom object prefixes vary per org
  and this technique must not be extended to them.
- If a future reviewer prefers explicitness over the micro-optimisation, the
  swap to `getSObjectType()` is a one-line change in one place.

## References

- `TaskRollupHelper.collectOpportunityIds`
- [Salesforce standard object key prefixes](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/)
